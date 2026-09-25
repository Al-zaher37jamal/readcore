import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';

const _room = 'RM-VOICE-LAN';
const _book = 'identical-pdf-on-both-phones';

class _Phone {
  final AppDatabase db = AppDatabase.memory();
  final Directory root;
  late final SessionRepository sessions = SessionRepositoryImpl(db);
  late final SessionContentRepository content = SessionContentRepository(db);
  late final ReadingProgressRepository progress = ReadingProgressRepositoryImpl(db);
  late final ParticipantReadingTimeRepository times = ParticipantReadingTimeRepositoryImpl(db);
  late final SessionVoiceStore voices = SessionVoiceStore(root);
  _Phone(this.root);

  Future<void> seed() async {
    await BookRepositoryImpl(db).createBook(id: _book, title: 'PDF',
        author: 'Author', filePath: '${root.path}/book.pdf', fileSize: 100,
        pageCount: 20, sha256Hash: 'same-pdf');
    await sessions.createSession(id: _room, title: 'Reading room',
        hostDeviceId: 'host', bookId: _book, status: 'active');
  }

  SessionContentSync bridge(String id, {LanHostServer? host,
      LanParticipantClient? participant}) => SessionContentSync(
    sessionId: _room, bookId: _book, deviceId: id,
    displayName: id, totalPages: 20, repository: content,
    voiceStore: voices, progressRepository: progress,
    readingTimeRepository: times, host: host, participant: participant,
  )..start();
}

Future<void> _awaitJoin(LanParticipantClient client, LanHostServer host) async {
  final ack = client.messageStream.firstWhere((m) =>
      m.type == LanMessageType.stateSnapshot).timeout(const Duration(seconds: 5));
  await client.connect(hostAddress: InternetAddress.loopbackIPv4.address,
      port: host.port);
  await ack;
  expect(client.hasJoinAck, isTrue);
  expect(client.isJoined, isTrue);
}

void main() {
  late Directory temp;
  late _Phone a, b, c;
  late LanHostServer server;
  late LanParticipantClient clientB, clientC;
  late SessionContentSync syncA, syncB, syncC;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('phase6_lan_');
    a = _Phone(Directory('${temp.path}/a'));
    b = _Phone(Directory('${temp.path}/b'));
    c = _Phone(Directory('${temp.path}/c'));
    await a.seed(); await b.seed(); await c.seed();
    server = LanHostServer(sessionId: _room, hostDeviceId: 'host',
        hostDisplayName: 'Host', initialPage: 1, totalPages: 20,
        sessionStatus: 'active', requestedPort: 0);
    clientB = LanParticipantClient(sessionId: _room, deviceId: 'phone-b',
        displayName: 'Phone B', autoReconnect: false);
    clientC = LanParticipantClient(sessionId: _room, deviceId: 'phone-c',
        displayName: 'Phone C', autoReconnect: false);
    await server.start(bindAddress: InternetAddress.loopbackIPv4);
    syncA = a.bridge('host', host: server);
    syncB = b.bridge('phone-b', participant: clientB);
    syncC = c.bridge('phone-c', participant: clientC);
    await _awaitJoin(clientB, server);
  });

  tearDown(() async {
    await syncA.dispose(); await syncB.dispose(); await syncC.dispose();
    await clientB.disconnect(); await clientC.disconnect();
    clientB.dispose(); clientC.dispose();
    await server.stop(); server.dispose();
    await a.db.close(); await b.db.close(); await c.db.close();
    await temp.delete(recursive: true);
  });

  test('Host relays only shared page notes/highlights, pins and Unicode discussion', () async {
    final secret = await syncB.addNote(5, 'Personal only', shared: false);
    final sharedSeen = a.content.watchAnnotations(_room, 5, 'host').firstWhere(
        (list) => list.any((n) => n.content == 'Shared note'))
        .timeout(const Duration(seconds: 5));
    final note = await syncB.addNote(5, 'Shared note', shared: true);
    await sharedSeen;
    expect(await a.content.watchAnnotations(_room, 5, 'host').first,
        hasLength(1));
    expect(await a.content.watchAnnotations(_room, 5, 'unrelated-viewer').first,
        hasLength(1));
    expect((await b.content.watchAnnotations(_room, 5, 'phone-b').first).length, 2);
    // Even an explicitly forged personal packet must never leave the device.
    await clientB.sendAndFlush(LanMessage.contentUpsert(
        sessionId: _room, deviceId: 'phone-b', content: secret.toWire()));
    final pinSeen = a.content.watchAnnotations(_room, 5, 'host').firstWhere(
        (list) => list.isNotEmpty && list.single.isPinned)
        .timeout(const Duration(seconds: 5));
    await syncB.setPinned(note, true);
    expect((await pinSeen).single.id, note.id);
    expect(await a.content.sharedAnnotations(_room), hasLength(1));
    expect((await a.content.watchAnnotations(_room, 6, 'host').first), isEmpty);

    final markSeen = b.content.watchAnnotations(_room, 10, 'phone-b',
        kind: 'highlight').firstWhere((list) => list.isNotEmpty)
        .timeout(const Duration(seconds: 5));
    final mark = await syncA.addHighlight(10, 0.2, 0.3, 0.4, 0.1,
        shared: true, color: '#FFD54F');
    expect((await markSeen).single.id, mark.id);
    expect(await b.content.watchAnnotations(_room, 11, 'phone-b',
        kind: 'highlight').first, isEmpty);

    final hostMessage = a.content.watchDiscussion(_room, 10).firstWhere(
        (list) => list.any((m) => m.content == 'مرحبا 🌟'))
        .timeout(const Duration(seconds: 5));
    await syncB.sendText(10, 'مرحبا 🌟');
    expect((await hostMessage).single.authorId, 'phone-b');
    final wrongSender = LanMessage.contentUpsert(sessionId: _room,
        deviceId: 'not-phone-b', content: (await syncB.sendText(11, 'Valid')).toWire());
    await clientB.sendAndFlush(wrongSender);
    final validSeen = a.content.watchDiscussion(_room, 11).firstWhere(
        (list) => list.isNotEmpty).timeout(const Duration(seconds: 5));
    await validSeen;
    expect((await a.content.watchDiscussion(_room, 11).first).length, 1,
        reason: 'Host ignores content with a forged joined-socket sender ID');
  });

  test('voice chunks, hash, replay for late peer, progress and time per device', () async {
    final received = a.content.watchDiscussion(_room, 7).firstWhere((list) =>
        list.any((m) => m.kind == 'voice')).timeout(const Duration(seconds: 8));
    final source = await b.voices.fileFor(_room, 'voice_lan_test');
    final audio = Uint8List.fromList(List<int>.generate(35000, (i) => i % 251));
    await source.writeAsBytes(audio);
    await syncB.sendVoice(7, source, 1300, messageId: 'voice_lan_test');
    final onHost = (await received).single;
    expect(onHost.authorId, 'phone-b');
    expect(onHost.voiceBytes, audio.length);
    expect(await (await a.voices.fileFor(_room, onHost.id)).readAsBytes(), audio);
    expect(onHost.toWire().containsKey('voicePath'), isFalse);

    final lateVoice = c.content.watchDiscussion(_room, 7).firstWhere((list) =>
        list.any((m) => m.kind == 'voice')).timeout(const Duration(seconds: 10));
    await _awaitJoin(clientC, server);
    expect((await lateVoice).single.id, 'voice_lan_test');
    expect(await (await c.voices.fileFor(_room, 'voice_lan_test')).readAsBytes(), audio);
    expect(await c.content.watchDiscussion(_room, 6).first, isEmpty);

    final progressSeen = a.progress.watchSessionProgress(_room).firstWhere(
        (list) => list.any((p) => p.deviceId == 'phone-b' && p.currentPage == 10))
        .timeout(const Duration(seconds: 5));
    await syncB.reportProgress(10, 20);
    final progressRows = await progressSeen;
    expect(progressRows.singleWhere((p) => p.deviceId == 'phone-b').totalPages, 20);
    final hostTime = a.times.watchSessionTimes(_room).firstWhere((list) =>
        list.any((t) => t.deviceId == 'phone-b' && t.totalSeconds == 25))
        .timeout(const Duration(seconds: 5));
    await syncB.reportReadingTime(25);
    expect((await hostTime).single.totalSeconds, 25);
    await syncB.reportReadingTime(10); // delayed packet must not decrement
    final cTime = a.times.watchSessionTimes(_room).firstWhere((list) =>
        list.any((t) => t.deviceId == 'phone-c' && t.totalSeconds == 40))
        .timeout(const Duration(seconds: 5));
    await syncC.reportReadingTime(40);
    await cTime;
    expect((await a.times.getTime(_room, 'phone-b'))!.totalSeconds, 25);
    expect((await a.times.getTime(_room, 'phone-c'))!.totalSeconds, 40);
  });

  test('reconnect retries offline-authored messages and retained voice without new session', () async {
    await clientB.disconnect();
    final note = await syncB.addNote(12, 'Written offline', shared: true);
    await syncB.sendText(12, 'Offline discussion');
    final file = await b.voices.fileFor(_room, 'voice_offline');
    final bytes = Uint8List.fromList(List<int>.generate(20000, (i) => i % 227));
    await file.writeAsBytes(bytes);
    await syncB.sendVoice(12, file, 900, messageId: 'voice_offline');
    await b.times.addReadingTime(id: 'b-time', sessionId: _room,
        deviceId: 'phone-b', additionalSeconds: 14);
    await b.progress.updateProgress(id: 'b-progress', sessionId: _room,
        bookId: _book, deviceId: 'phone-b', currentPage: 12, totalPages: 20);
    expect(await a.content.sharedAnnotations(_room), isEmpty);
    final sharedSeen = a.content.watchAnnotations(_room, 12, 'host')
        .firstWhere((list) => list.any((n) => n.id == note.id))
        .timeout(const Duration(seconds: 8));
    final voiceSeen = a.content.watchDiscussion(_room, 12)
        .firstWhere((list) => list.any((m) => m.kind == 'voice'))
        .timeout(const Duration(seconds: 10));
    await _awaitJoin(clientB, server);
    await sharedSeen;
    final restored = await voiceSeen;
    expect(restored.length, 2);
    expect((await a.progress.getProgress(_room, 'phone-b'))!.currentPage, 12);
    expect((await a.times.getTime(_room, 'phone-b'))!.totalSeconds, 14);
    expect(await (await a.voices.fileFor(_room, 'voice_offline')).readAsBytes(), bytes);
    expect((await a.sessions.getAllSessions()).single.id, _room);
  });
}
