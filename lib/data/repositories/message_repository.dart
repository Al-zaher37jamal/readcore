import 'dart:async';

import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/features/text_messages/domain/text_message.dart';

/// Existing message repository, extended with page-scoped, local-only text
/// operations. Older Phase 1–5 callers retain their original API.
abstract class MessageRepository {
  Future<Message> sendMessage({
    required String id,
    required String sessionId,
    required String senderId,
    required String senderName,
    required String content,
    String messageType = 'text',
  });

  Future<List<Message>> getMessages(String sessionId);
  Stream<List<Message>> watchMessages(String sessionId);
  Future<bool> deleteMessage(String id);

  Future<TextMessage> createText({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
    required String senderName,
    required String text,
  });
  Future<List<TextMessage>> getPageText(String sessionId, int pageNumber);
  Stream<List<TextMessage>> watchPageText(String sessionId, int pageNumber);
  Future<bool> updateOwnText({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
    required String text,
  });
  Future<bool> deleteOwnText({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
  });
}

class MessageRepositoryImpl implements MessageRepository {
  final AppDatabase _db;
  MessageRepositoryImpl(this._db);

  static const _selectPage = '''
SELECT id, session_id, page_number, sender_id, sender_name, content,
       created_at, updated_at, status
FROM messages
WHERE session_id = ? AND page_number = ? AND message_type = 'text'
ORDER BY created_at ASC, rowid ASC
''';

  static int _secondsNow() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  static void _validatePage(String sessionId, int pageNumber) {
    if (sessionId.isEmpty || sessionId.length > 150 ||
        pageNumber < 1 || pageNumber > 10000) {
      throw const FormatException('Invalid session or page');
    }
  }

  static String _validatedText(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty || cleaned.length > 2000) {
      throw const FormatException('Message must contain 1–2000 characters');
    }
    return cleaned;
  }

  @override
  Future<TextMessage> createText({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    _validatePage(sessionId, pageNumber);
    final cleaned = _validatedText(text);
    if (id.isEmpty || id.length > 100 || senderId.isEmpty ||
        senderId.length > 100 || senderName.trim().isEmpty ||
        senderName.length > 100) {
      throw const FormatException('Invalid message identity');
    }
    return _db.writeTx(() async {
      // Session FK protects against orphan messages; a terminal session is
      // deliberately read-only. No network, LAN or outbox operation is used.
      final session = await _db.customSelect(
        'SELECT status FROM sessions WHERE id = ?',
        variables: [Variable.withString(sessionId)],
      ).getSingleOrNull();
      if (session == null ||
          !const {'created', 'active', 'paused'}
              .contains(session.data['status'])) {
        throw StateError('Session is not open for new messages');
      }
      final now = _secondsNow();
      await _db.customUpdate('''
INSERT INTO messages (id, session_id, page_number, sender_id, sender_name,
  content, message_type, created_at, updated_at, status)
VALUES (?, ?, ?, ?, ?, ?, 'text', ?, ?, 'local')
''', variables: [
        Variable.withString(id), Variable.withString(sessionId),
        Variable.withInt(pageNumber), Variable.withString(senderId),
        Variable.withString(senderName.trim()), Variable.withString(cleaned),
        Variable.withInt(now), Variable.withInt(now),
      ], updates: {_db.messagesTable});
      final row = await _db.customSelect(
        'SELECT id, session_id, page_number, sender_id, sender_name, '
        'content, created_at, updated_at, status FROM messages WHERE id = ?',
        variables: [Variable.withString(id)],
      ).getSingle();
      return TextMessage.fromRow(row.data);
    });
  }

  @override
  Future<List<TextMessage>> getPageText(String sessionId, int pageNumber) async {
    _validatePage(sessionId, pageNumber);
    final rows = await _db.customSelect(_selectPage, variables: [
      Variable.withString(sessionId), Variable.withInt(pageNumber),
    ]).get();
    return rows.map((row) => TextMessage.fromRow(row.data)).toList();
  }

  @override
  Stream<List<TextMessage>> watchPageText(String sessionId, int pageNumber) {
    _validatePage(sessionId, pageNumber);
    return _db.customSelect(_selectPage, variables: [
      Variable.withString(sessionId), Variable.withInt(pageNumber),
    ], readsFrom: {_db.messagesTable}).watch().map(
      (rows) => rows.map((row) => TextMessage.fromRow(row.data)).toList(),
    );
  }

  @override
  Future<bool> updateOwnText({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
    required String text,
  }) {
    _validatePage(sessionId, pageNumber);
    final cleaned = _validatedText(text);
    return _db.writeTx(() async {
      final changed = await _db.customUpdate('''
UPDATE messages SET content = ?, updated_at = ?
WHERE id = ? AND session_id = ? AND page_number = ?
  AND sender_id = ? AND message_type = 'text'
''', variables: [
        Variable.withString(cleaned), Variable.withInt(_secondsNow()),
        Variable.withString(id), Variable.withString(sessionId),
        Variable.withInt(pageNumber), Variable.withString(senderId),
      ], updates: {_db.messagesTable});
      return changed > 0;
    });
  }

  @override
  Future<bool> deleteOwnText({
    required String id,
    required String sessionId,
    required int pageNumber,
    required String senderId,
  }) {
    _validatePage(sessionId, pageNumber);
    return _db.writeTx(() async {
      final changed = await _db.customUpdate('''
DELETE FROM messages WHERE id = ? AND session_id = ? AND page_number = ?
  AND sender_id = ? AND message_type = 'text'
''', variables: [
        Variable.withString(id), Variable.withString(sessionId),
        Variable.withInt(pageNumber), Variable.withString(senderId),
      ], updates: {_db.messagesTable});
      return changed > 0;
    });
  }

  // Legacy API. These inserts default to page 1; preserve older consumers.
  @override
  Future<Message> sendMessage({
    required String id,
    required String sessionId,
    required String senderId,
    required String senderName,
    required String content,
    String messageType = 'text',
  }) async {
    final companion = MessagesTableCompanion.insert(
      id: id,
      sessionId: sessionId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      messageType: messageType,
      createdAt: DateTime.now().toUtc(),
    );
    return _db.writeTx(() async {
      await _db.into(_db.messagesTable).insert(companion);
      return (_db.select(_db.messagesTable)..where((t) => t.id.equals(id)))
          .getSingle();
    });
  }

  @override
  Future<List<Message>> getMessages(String sessionId) {
    return (_db.select(_db.messagesTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  @override
  Stream<List<Message>> watchMessages(String sessionId) {
    return (_db.select(_db.messagesTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  @override
  Future<bool> deleteMessage(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.messagesTable)
            ..where((t) => t.id.equals(id)))
          .go();
      return count > 0;
    });
  }
}
