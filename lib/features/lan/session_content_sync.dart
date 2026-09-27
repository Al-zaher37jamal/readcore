import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/text_messages/domain/text_message.dart';
import 'lan_host_server.dart';
import 'lan_message.dart';
import 'lan_participant_client.dart';

/// Adds Phase 6 content to the Phase 4 TCP transport; no extra listener or
/// network dependency. Each phone commits locally first. Shared content is
/// replayed by ID after reconnect and when a new participant joins.
class SessionContentSync {
  static const int voiceChunkSize = 16384;

  final String sessionId, bookId, deviceId, displayName;
  final int totalPages;
  final SessionContentRepository repository;
  final SessionVoiceStore voiceStore;
  final ReadingProgressRepository? progressRepository;
  final ParticipantReadingTimeRepository? readingTimeRepository;
  final LanHostServer? host;
  final LanParticipantClient? participant;

  StreamSubscription<LanMessage>? _subscription;
  Future<void> _inboundQueue = Future<void>.value();
  Future<void> _progressQueue = Future<void>.value();
  final Map<String, _VoiceAssembly> _incoming = {};
  final StreamController<String> _errors = StreamController<String>.broadcast();
  int _replayGeneration = 0;
  bool _disposed = false;

  SessionContentSync({
    required this.sessionId, required this.bookId,
    required this.deviceId, required this.displayName,
    required this.totalPages, required this.repository, required this.voiceStore,
    this.progressRepository, this.readingTimeRepository, this.host, this.participant,
  });

  Stream<String> get errors => _errors.stream;

  // A participant can attach before the TCP snapshot arrives, or have no
  // local copy of the PDF. Once known, the Host's count is authoritative,
  // even when a stale local page count differs from it.
  int get _contentPageLimit {
    final livePages = participant?.hasSnapshot == true
        ? participant!.totalPages : host?.totalPages;
    return livePages != null && livePages > 0 ? livePages : totalPages;
  }

  void start() {
    if (_subscription != null || _disposed) return;
    if (host != null) {
      _subscription = host!.messageStream.listen((message) {
        if (message.sessionId == sessionId) _queue(message, fromParticipant: true);
      });
      // A peer might have joined before the Host's content listener attached.
      for (final target in host!.joinedPeersForInitialBacklog()) {
        unawaited(_sendBacklog(target).catchError((Object error) {
          _error('Could not send saved content: $error');
        }));
      }
    } else if (participant != null) {
      _subscription = participant!.messageStream.listen((message) {
        if (message.sessionId == sessionId) _queue(message, fromParticipant: false);
      });
      if (participant!.isJoined) {
        // RoomsScreen's preflight can consume the initial snapshot and drop
        // the Host's join backlog before this subscriber exists. Request a
        // one-shot catch-up on the same socket, then replay local rows by ID.
        unawaited(_requestMissedBacklog().catchError((Object error) {
          _error('Could not request saved content: $error');
        }));
        _scheduleReplay();
      }
    }
  }

  void _queue(LanMessage packet, {required bool fromParticipant}) {
    // TCP preserves order, but an async file/database write could otherwise let
    // a voice chunk overtake its metadata or the preceding chunk.
    _inboundQueue = _inboundQueue.catchError((_) {}).then((_) =>
        _receive(packet, fromParticipant: fromParticipant));
  }

  Future<SessionAnnotation> addNote(int page, String content,
      {required bool shared, String color = '#FFF59D'}) async {
    final now = DateTime.now().toUtc();
    final note = SessionAnnotation(
      id: 'note_${const Uuid().v4()}', sessionId: sessionId, bookId: bookId,
      pageNumber: page, authorId: deviceId, authorName: displayName,
      content: content.trim(), color: color, kind: 'note',
      visibility: shared ? 'shared' : 'personal', isPinned: false,
      createdAt: now, updatedAt: now,
    );
    await repository.saveAnnotation(note);
    if (shared) await _publishAnnotation(note);
    return note;
  }

  Future<SessionAnnotation> addHighlight(int page, double x, double y,
      double width, double height, {required bool shared,
      String color = '#FFF59D'}) async {
    final now = DateTime.now().toUtc();
    final mark = SessionAnnotation(
      id: 'mark_${const Uuid().v4()}', sessionId: sessionId, bookId: bookId,
      pageNumber: page, authorId: deviceId, authorName: displayName,
      content: '', color: color, kind: 'highlight',
      visibility: shared ? 'shared' : 'personal', isPinned: false,
      x: x, y: y, width: width, height: height,
      createdAt: now, updatedAt: now,
    );
    await repository.saveAnnotation(mark);
    if (shared) await _publishAnnotation(mark);
    return mark;
  }

  Future<void> setPinned(SessionAnnotation note, bool pinned) async {
    if (note.sessionId != sessionId || note.authorId != deviceId ||
        note.kind != 'note') throw StateError('Only the author can pin a note.');
    final updated = note.pin(pinned);
    await repository.saveAnnotation(updated);
    if (updated.visibility == 'shared') await _publishAnnotation(updated);
  }

  /// Publish a text row already committed by the unified Reader composer.
  /// MessageRepository and SessionContentRepository share `messages`: never
  /// insert the same row twice or assign a second LAN identity. A disconnected
  /// peer retains the row for the existing join replay.
  Future<bool> publishCommittedText(TextMessage message) async {
    if (message.sessionId != sessionId || message.senderId != deviceId ||
        message.pageNumber < 1 || message.pageNumber > _contentPageLimit) {
      throw StateError('Committed text does not belong to this LAN session');
    }
    final entry = SessionDiscussion(
      id: message.id, sessionId: message.sessionId,
      pageNumber: message.pageNumber, authorId: message.senderId,
      authorName: message.senderName, content: message.text,
      kind: 'text', createdAt: message.createdAt,
    );
    entry.validate();
    return _send(LanMessage.contentUpsert(sessionId: sessionId,
        deviceId: deviceId, content: entry.toWire()));
  }

  Future<SessionDiscussion> sendText(int page, String content) async {
    final message = SessionDiscussion(
      id: 'msg_${const Uuid().v4()}', sessionId: sessionId,
      pageNumber: page, authorId: deviceId, authorName: displayName,
      content: content.trim(), kind: 'text', createdAt: DateTime.now().toUtc(),
    );
    await repository.saveDiscussion(message);
    await _send(LanMessage.contentUpsert(
      sessionId: sessionId, deviceId: deviceId, content: message.toWire()));
    return message;
  }

  /// The recorder writes this private file before metadata is published.
  /// Even offline, the audio is saved locally and retried at the next join.
  Future<SessionDiscussion> sendVoice(int page, File file, int durationMs,
      {String? messageId}) async {
    final id = messageId ?? 'voice_${const Uuid().v4()}';
    final allowed = await voiceStore.fileFor(sessionId, id);
    if (file.absolute.path != allowed.absolute.path) {
      throw const FormatException('Recording outside session voice directory');
    }
    final info = await voiceStore.inspect(file);
    final message = SessionDiscussion(
      id: id, sessionId: sessionId, pageNumber: page,
      authorId: deviceId, authorName: displayName,
      content: '', kind: 'voice', createdAt: DateTime.now().toUtc(),
      voicePath: allowed.path, durationMs: durationMs,
      voiceBytes: info.bytes, voiceSha256: info.sha256,
    );
    await repository.saveDiscussion(message);
    await _sendVoice(message);
    return message;
  }

  /// Reader progress is private per device, but the Host can display the last
  /// reported page for each participant alongside its local roster.
  Future<void> reportProgress(int page, int total) async {
    if (participant == null || page < 1 || total < page) return;
    // Serialize rapid updates so an earlier page cannot arrive after a later one.
    final sending = _progressQueue.catchError((_) {}).then((_) => _send(
      LanMessage.participantProgress(sessionId: sessionId, deviceId: deviceId,
          page: page, totalPages: total)));
    _progressQueue = sending.then<void>((_) {});
    await sending;
  }

  Future<void> reportReadingTime(int totalSeconds) async {
    if (participant == null || totalSeconds < 0 ||
        totalSeconds > 3153600000) return;
    await _send(LanMessage.participantTime(sessionId: sessionId,
        deviceId: deviceId, totalSeconds: totalSeconds));
  }

  Future<void> _publishAnnotation(SessionAnnotation note) async {
    await _send(LanMessage.contentUpsert(sessionId: sessionId,
        deviceId: deviceId, content: note.toWire()));
  }

  Future<void> _requestMissedBacklog() async {
    if (_disposed || participant?.isJoined != true) return;
    await _send(LanMessage.contentReplayRequest(
        sessionId: sessionId, deviceId: deviceId));
  }

  Future<bool> _send(LanMessage message, {String? toDevice}) async {
    if (_disposed) return false;
    if (host != null) {
      if (toDevice != null) return host!.sendToParticipant(toDevice, message);
      var sent = true;
      for (final peer in host!.participants) {
        if (!await host!.sendToParticipant(peer.deviceId, message)) sent = false;
      }
      return sent;
    }
    return participant?.sendAndFlush(message) ?? Future<bool>.value(false);
  }

  Future<void> _sendVoice(SessionDiscussion voice, {String? toDevice}) async {
    if (_disposed) return;
    final file = await voiceStore.fileFor(sessionId, voice.id);
    if (!await file.exists()) return;
    final info = await voiceStore.inspect(file);
    if (info.bytes != voice.voiceBytes || info.sha256 != voice.voiceSha256) {
      _error('Voice file changed before it could be shared');
      return;
    }
    if (!await _send(LanMessage.contentUpsert(
        sessionId: sessionId, deviceId: deviceId, content: voice.toWire()),
        toDevice: toDevice)) return;
    final count = (info.bytes + voiceChunkSize - 1) ~/ voiceChunkSize;
    final input = await file.open();
    try {
      for (var i = 0; i < count; i++) {
        final chunk = await input.read(voiceChunkSize);
        if (!await _send(LanMessage.voiceChunk(
            sessionId: sessionId, deviceId: deviceId, messageId: voice.id,
            index: i, total: count, bytesBase64: base64Encode(chunk)),
            toDevice: toDevice)) return;
      }
    } finally {
      await input.close();
    }
  }

  Future<void> _receive(LanMessage message, {required bool fromParticipant}) async {
    if (_disposed) return;
    try {
      switch (message.type) {
        case LanMessageType.join:
        case LanMessageType.contentReplayRequest:
          if (fromParticipant && host!.hasParticipant(message.senderDeviceId) &&
              (message.type == LanMessageType.join ||
                  host!.claimContentBacklog(message.senderDeviceId))) {
            unawaited(_sendBacklog(message.senderDeviceId).catchError((Object error) {
              _error('Could not send saved content: $error');
            }));
          }
          break;
        case LanMessageType.stateSnapshot:
          if (!fromParticipant && participant?.isJoined == true) {
            _scheduleReplay();
          }
          break;
        case LanMessageType.participantProgress:
          if (fromParticipant && progressRepository != null &&
              message.currentPage != null && message.totalPages != null &&
              message.currentPage! >= 1 && message.currentPage! <= totalPages &&
              message.totalPages! >= message.currentPage! &&
              message.totalPages! <= 10000) {
            await progressRepository!.updateProgress(
              id: 'prog_${sessionId}_${bookId}_${message.senderDeviceId}',
              sessionId: sessionId, bookId: bookId,
              deviceId: message.senderDeviceId,
              currentPage: message.currentPage!, totalPages: message.totalPages!,
            );
          }
          break;
        case LanMessageType.participantTime:
          final seconds = message.payload?['totalSeconds'];
          if (fromParticipant && readingTimeRepository != null &&
              seconds is int && seconds >= 0 && seconds <= 3153600000) {
            await readingTimeRepository!.setTimeAtLeast(
              id: 'time_${sessionId}_${message.senderDeviceId}',
              sessionId: sessionId, deviceId: message.senderDeviceId,
              totalSeconds: seconds,
            );
          }
          break;
        case LanMessageType.contentUpsert:
          await _receiveContent(message, fromParticipant: fromParticipant);
          break;
        case LanMessageType.voiceChunk:
          await _receiveVoiceChunk(message, fromParticipant: fromParticipant);
          break;
        default:
          break; // Phase 4 page and session messages remain authoritative.
      }
    } catch (error) {
      _error('Could not synchronize session content: $error');
    }
  }

  Future<void> _receiveContent(LanMessage packet,
      {required bool fromParticipant}) async {
    final data = packet.payload;
    // A valid 2,000-character text may exceed 4 KB after JSON escaping
    // (e.g. Arabic/emoji, up to 12 code units per escaped surrogate pair).
    // Bound it below the TCP line cap; decoded entries are also validated.
    if (data == null || data['sessionId'] != sessionId ||
        packet.serialize().length > 32768) return;
    if (data['kind'] == 'note' || data['kind'] == 'highlight') {
      final note = SessionAnnotation.fromWire(data, bookId: bookId);
      if (note.visibility != 'shared' || note.pageNumber > _contentPageLimit ||
          (fromParticipant && note.authorId != packet.senderDeviceId)) return;
      await repository.saveAnnotation(note);
      if (fromParticipant) {
        await _send(LanMessage.contentUpsert(
            sessionId: sessionId, deviceId: deviceId, content: note.toWire()));
      }
    } else if (data['kind'] == 'text' || data['kind'] == 'voice') {
      // The voice path is always computed locally. Never read a path from LAN.
      final id = data['id'];
      final localFile = data['kind'] == 'voice' && id is String
          ? await voiceStore.fileFor(sessionId, id) : null;
      final entry = SessionDiscussion.fromWire(data,
          localVoicePath: localFile?.path);
      if (entry.pageNumber > _contentPageLimit ||
          (fromParticipant && entry.authorId != packet.senderDeviceId)) return;
      if (entry.kind == 'voice') {
        final old = await repository.getDiscussionById(entry.id);
        if (old != null && (old.sessionId != entry.sessionId ||
            old.authorId != entry.authorId || old.kind != entry.kind ||
            old.pageNumber != entry.pageNumber ||
            old.voiceSha256 != entry.voiceSha256 ||
            old.voiceBytes != entry.voiceBytes)) {
          throw const FormatException('Conflicting voice metadata');
        }
      }
      if (entry.kind == 'text') {
        final inserted = await repository.saveDiscussion(entry);
        // A reconnect can replay the same ID; never relay it twice. The
        // joining peer receives the Host's stored copy from the backlog.
        if (fromParticipant && inserted) {
          await _send(LanMessage.contentUpsert(sessionId: sessionId,
              deviceId: deviceId, content: entry.toWire()));
        }
      } else if (localFile != null && await localFile.exists() &&
          (await voiceStore.inspect(localFile)).sha256 == entry.voiceSha256) {
        await repository.saveDiscussion(entry);
        if (fromParticipant) await _sendVoice(entry);
      } else {
        final existing = _incoming[entry.id];
        if (existing == null) {
          // Bound memory even if a peer never finishes a transfer. A repeated
          // metadata packet can start the evicted transfer again on reconnect.
          if (_incoming.length >= 4) _incoming.remove(_incoming.keys.first);
          _incoming[entry.id] = _VoiceAssembly(entry, packet.senderDeviceId);
        } else if (existing.sender != packet.senderDeviceId ||
            existing.message.voiceSha256 != entry.voiceSha256) {
          throw const FormatException('Conflicting voice transfer');
        }
      }
    }
  }

  Future<void> _receiveVoiceChunk(LanMessage packet,
      {required bool fromParticipant}) async {
    final data = packet.payload;
    if (data == null) return;
    final id = data['id'];
    final pending = _incoming[id];
    if (pending == null || pending.completing ||
        pending.sender != packet.senderDeviceId ||
        data['index'] is! int || data['total'] is! int ||
        data['bytes'] is! String ||
        (data['bytes'] as String).length > 22000) return;
    final index = data['index'] as int;
    final total = data['total'] as int;
    final expected = (pending.message.voiceBytes! + voiceChunkSize - 1) ~/ voiceChunkSize;
    if (total != expected || index < 0 || index >= total ||
        pending.chunks.containsKey(index)) return;
    final bytes = base64Decode(data['bytes'] as String);
    if (bytes.isEmpty || bytes.length > voiceChunkSize ||
        pending.receivedBytes + bytes.length > SessionVoiceStore.maxVoiceBytes) {
      _incoming.remove(id);
      return;
    }
    pending.chunks[index] = bytes;
    pending.receivedBytes += bytes.length;
    if (pending.chunks.length != expected) return;
    pending.completing = true;
    if (pending.receivedBytes != pending.message.voiceBytes) {
      _incoming.remove(id);
      return;
    }
    final joined = Uint8List(pending.receivedBytes);
    var offset = 0;
    for (var i = 0; i < expected; i++) {
      final piece = pending.chunks[i]!;
      joined.setRange(offset, offset + piece.length, piece);
      offset += piece.length;
    }
    try {
      await voiceStore.saveVerified(sessionId, pending.message.id,
          joined, pending.message.voiceSha256!);
      await repository.saveDiscussion(pending.message);
      if (fromParticipant) await _sendVoice(pending.message);
    } finally {
      _incoming.remove(id);
    }
  }

  Future<void> _sendBacklog(String target) async {
    if (_disposed) return;
    final notes = await repository.sharedAnnotations(sessionId);
    for (final note in notes) {
      if (!await _send(LanMessage.contentUpsert(sessionId: sessionId,
          deviceId: deviceId, content: note.toWire()), toDevice: target)) return;
    }
    final discussions = await repository.sessionDiscussion(sessionId);
    for (final message in discussions) {
      if (message.kind == 'voice') {
        await _sendVoice(message, toDevice: target);
      } else if (!await _send(LanMessage.contentUpsert(
          sessionId: sessionId, deviceId: deviceId,
          content: message.toWire()), toDevice: target)) return;
    }
  }

  void _scheduleReplay() {
    unawaited(_replayToHost(++_replayGeneration).catchError((Object error) {
      _error('Could not replay saved content: $error');
    }));
  }

  Future<void> _replayToHost(int generation) async {
    if (_disposed || participant?.isJoined != true) return;
    // Report the saved, device-specific page BEFORE Reader adopts the Host's
    // live page. The later page event will report the new synced position.
    final progress = await progressRepository?.getProgress(sessionId, deviceId);
    if (progress != null) {
      await reportProgress(progress.currentPage, progress.totalPages);
    }
    final time = await readingTimeRepository?.getTime(sessionId, deviceId);
    if (time != null) await reportReadingTime(time.totalSeconds);
    for (final note in await repository.sharedAnnotations(sessionId)) {
      if (_disposed || generation != _replayGeneration) return;
      if (note.authorId != deviceId) continue; // A peer never impersonates another author.
      if (!await _send(LanMessage.contentUpsert(sessionId: sessionId,
          deviceId: deviceId, content: note.toWire()))) return;
    }
    for (final message in await repository.sessionDiscussion(sessionId)) {
      if (_disposed || generation != _replayGeneration) return;
      if (message.authorId != deviceId) continue; // Host owns others' replay.
      if (message.kind == 'voice') {
        await _sendVoice(message);
      } else if (!await _send(LanMessage.contentUpsert(
          sessionId: sessionId, deviceId: deviceId,
          content: message.toWire()))) return;
    }
  }

  void _error(String text) {
    if (!_errors.isClosed) _errors.add(text);
  }

  Future<void> dispose() async {
    _disposed = true;
    _replayGeneration++;
    _incoming.clear();
    await _subscription?.cancel();
    host?.resetContentBacklogClaims();
    await _errors.close();
  }
}

class _VoiceAssembly {
  final SessionDiscussion message;
  final String sender;
  final Map<int, Uint8List> chunks = {};
  int receivedBytes = 0;
  bool completing = false;
  _VoiceAssembly(this.message, this.sender);
}
