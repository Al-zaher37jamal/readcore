import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

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
}

class MessageRepositoryImpl implements MessageRepository {
  final AppDatabase _db;

  MessageRepositoryImpl(this._db);

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
      return (await (_db.select(_db.messagesTable)..where((t) => t.id.equals(id))).getSingle());
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
      final count = await (_db.delete(_db.messagesTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }
}
