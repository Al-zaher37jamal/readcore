import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/audio_messages/domain/audio_message.dart';

/// Local-only audio messages in the existing Drift `messages` table.
/// Text CRUD and the legacy Notes/Voice tables/APIs remain unchanged.
abstract class AudioMessageRepository {
  Stream<List<AudioMessage>> watchPage(String sessionId, int pageNumber);
  Future<List<AudioMessage>> getPage(String sessionId, int pageNumber);

  /// The draft has already been recorded and previewed. Nothing is written to
  /// SQLite until this method is called by the Send action.
  Future<AudioMessage> send({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
    required String senderDisplayName,
    required File draft,
    required int durationMs,
    AudioMessage? replacing,
  });

  Future<bool> deleteOwn(AudioMessage message, String senderId);

  /// Call during application bootstrap, before a recorder can be active.
  Future<int> pruneUnreferencedFiles();
}

class AudioMessageRepositoryImpl implements AudioMessageRepository {
  final AppDatabase _db;
  final SessionVoiceStore _files;

  AudioMessageRepositoryImpl(this._db, this._files);

  static const _selectPage = '''
SELECT id, session_id, page_number, sender_id, sender_name, voice_path,
       duration_ms, voice_sha256, voice_bytes, created_at, updated_at, status,
       rowid AS local_order
FROM messages
WHERE session_id = ? AND page_number = ? AND message_type = 'audio'
ORDER BY created_at ASC, rowid ASC
''';
  static const _selectId = '''
SELECT id, session_id, page_number, sender_id, sender_name, voice_path,
       duration_ms, voice_sha256, voice_bytes, created_at, updated_at, status,
       rowid AS local_order
FROM messages
WHERE id = ? AND session_id = ? AND page_number = ?
  AND sender_id = ? AND message_type = 'audio'
''';

  static void _checkPage(String sessionId, int pageNumber) {
    if (sessionId.isEmpty || sessionId.length > 150 ||
        pageNumber < 1 || pageNumber > 10000) {
      throw const FormatException('Invalid audio session or page');
    }
  }

  static void _checkId(String id) {
    if (id.length > 94 ||
        !RegExp(r'^audio_[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid local audio ID');
    }
  }

  static String _displayName(String value) {
    final name = value.trim();
    // DeviceService uses Reader_<random ID> until a display name is chosen.
    return name.isEmpty || RegExp(r'^Reader_[A-Za-z0-9_-]+$').hasMatch(name)
        ? 'Local reader' : name;
  }

  static int _secondsNow() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  @override
  Stream<List<AudioMessage>> watchPage(String sessionId, int pageNumber) {
    _checkPage(sessionId, pageNumber);
    return _db.customSelect(_selectPage, variables: [
      Variable.withString(sessionId), Variable.withInt(pageNumber),
    ], readsFrom: {_db.messagesTable}).watch().map(
      (rows) => rows.map((row) => AudioMessage.fromRow(row.data)).toList(),
    );
  }

  @override
  Future<List<AudioMessage>> getPage(String sessionId, int pageNumber) async {
    _checkPage(sessionId, pageNumber);
    final rows = await _db.customSelect(_selectPage, variables: [
      Variable.withString(sessionId), Variable.withInt(pageNumber),
    ]).get();
    return rows.map((row) => AudioMessage.fromRow(row.data)).toList();
  }

  @override
  Future<AudioMessage> send({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
    required String senderDisplayName,
    required File draft,
    required int durationMs,
    AudioMessage? replacing,
  }) async {
    _checkId(id);
    _checkPage(sessionId, pageNumber);
    if (senderId.isEmpty || senderId.length > 100 ||
        durationMs < 1 || durationMs > 65000) {
      throw const FormatException('Invalid audio sender or duration');
    }
    final expectedDraft = await _files.fileFor(sessionId, 'draft_$id');
    if (p.normalize(expectedDraft.absolute.path) !=
        p.normalize(draft.absolute.path)) {
      throw const FormatException('Recording is outside the session');
    }
    final info = await _files.inspect(draft);
    final savedFile = await _files.fileFor(sessionId, id);
    if (await savedFile.exists()) {
      throw StateError('Audio ID already has a local file');
    }

    File? oldFile;
    if (replacing != null) {
      _checkId(replacing.id);
      if (replacing.sessionId != sessionId ||
          replacing.pageNumber != pageNumber ||
          replacing.senderId != senderId ||
          !await _files.isMessageFile(sessionId, replacing.id,
              replacing.audioPath)) {
        throw StateError('Only the local owner can replace this recording');
      }
      oldFile = await _files.fileFor(sessionId, replacing.id);
    }

    // Rename before the SQL transaction. If SQL fails, restore the preview;
    // if the process is killed between the two operations, startup GC removes
    // only our unreferenced audio file. Other voice files are never pruned.
    await draft.rename(savedFile.path);
    late final AudioMessage committed;
    try {
      committed = await _db.writeTx(() async {
        final session = await _db.customSelect(
          'SELECT status FROM sessions WHERE id = ?',
          variables: [Variable.withString(sessionId)],
        ).getSingleOrNull();
        if (session == null ||
            !const {'created', 'active', 'paused'}
                .contains(session.data['status'])) {
          throw StateError('Session is not open for new messages');
        }
        if (replacing != null) {
          final old = await _db.customSelect(_selectId, variables: [
            Variable.withString(replacing.id), Variable.withString(sessionId),
            Variable.withInt(pageNumber), Variable.withString(senderId),
          ]).getSingleOrNull();
          if (old == null || old.data['voice_path'] != oldFile!.path) {
            throw StateError('Original audio is no longer available');
          }
        }
        final now = _secondsNow();
        await _db.customUpdate('''
INSERT INTO messages (id, session_id, page_number, sender_id, sender_name,
  content, message_type, created_at, updated_at, status, voice_path,
  duration_ms, voice_sha256, voice_bytes)
VALUES (?, ?, ?, ?, ?, '', 'audio', ?, ?, 'local', ?, ?, ?, ?)
''', variables: [
          Variable.withString(id), Variable.withString(sessionId),
          Variable.withInt(pageNumber), Variable.withString(senderId),
          Variable.withString(_displayName(senderDisplayName)),
          Variable.withInt(now), Variable.withInt(now),
          Variable.withString(savedFile.path), Variable.withInt(durationMs),
          Variable.withString(info.sha256), Variable.withInt(info.bytes),
        ], updates: {_db.messagesTable});
        if (replacing != null) {
          final removed = await _db.customUpdate('''
DELETE FROM messages WHERE id = ? AND session_id = ? AND page_number = ?
  AND sender_id = ? AND message_type = 'audio'
''', variables: [
            Variable.withString(replacing.id),
            Variable.withString(sessionId), Variable.withInt(pageNumber),
            Variable.withString(senderId),
          ], updates: {_db.messagesTable});
          if (removed != 1) throw StateError('Original audio changed');
        }
        final row = await _db.customSelect(_selectId, variables: [
          Variable.withString(id), Variable.withString(sessionId),
          Variable.withInt(pageNumber), Variable.withString(senderId),
        ]).getSingle();
        return AudioMessage.fromRow(row.data);
      });
    } catch (_) {
      // Keep the recorded preview for retry if the DB is temporarily unavailable.
      if (await savedFile.exists()) {
        try {
          await savedFile.rename(draft.path);
        } on FileSystemException {
          // Startup reconciliation can remove the unreferenced final file.
        }
      }
      rethrow;
    }

    if (oldFile != null) {
      try {
        if (await oldFile.exists()) await oldFile.delete();
      } on FileSystemException {
        // New metadata has committed. A future startup sweep removes the
        // now-unreferenced old file rather than claiming Send failed.
      }
    }
    return committed;
  }

  @override
  Future<bool> deleteOwn(AudioMessage message, String senderId) async {
    _checkId(message.id);
    _checkPage(message.sessionId, message.pageNumber);
    if (message.senderId != senderId ||
        !await _files.isMessageFile(message.sessionId, message.id,
            message.audioPath)) {
      return false;
    }
    final file = await _files.fileFor(message.sessionId, message.id);
    final removed = await _db.writeTx(() async {
      final row = await _db.customSelect(_selectId, variables: [
        Variable.withString(message.id), Variable.withString(message.sessionId),
        Variable.withInt(message.pageNumber), Variable.withString(senderId),
      ]).getSingleOrNull();
      if (row == null || row.data['voice_path'] != file.path) return false;
      final count = await _db.customUpdate('''
DELETE FROM messages WHERE id = ? AND session_id = ? AND page_number = ?
  AND sender_id = ? AND message_type = 'audio'
''', variables: [
        Variable.withString(message.id), Variable.withString(message.sessionId),
        Variable.withInt(message.pageNumber), Variable.withString(senderId),
      ], updates: {_db.messagesTable});
      return count == 1;
    });
    if (removed && await file.exists()) await file.delete();
    return removed;
  }

  @override
  Future<int> pruneUnreferencedFiles() async {
    final rows = await _db.customSelect('''
SELECT voice_path FROM messages WHERE message_type = 'audio'
  AND voice_path IS NOT NULL
''').get();
    return _files.pruneUnreferencedAudio(
      rows.map((row) => row.read<String>('voice_path')).toSet(),
    );
  }
}
