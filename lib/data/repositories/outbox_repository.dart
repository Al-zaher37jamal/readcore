import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class OutboxRepository {
  Future<OutboxEntry> enqueue({
    required String id,
    String? sessionId,
    required String messageType,
    required String payload,
  });

  Future<List<OutboxEntry>> getPending();
  Future<bool> updateStatus(String id, String status);
  Future<bool> incrementRetry(String id);
  Future<bool> remove(String id);
  Stream<List<OutboxEntry>> watchPending();
}

class OutboxRepositoryImpl implements OutboxRepository {
  final AppDatabase _db;

  OutboxRepositoryImpl(this._db);

  @override
  Future<OutboxEntry> enqueue({
    required String id,
    String? sessionId,
    required String messageType,
    required String payload,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = OutboxTableCompanion.insert(
      id: id,
      sessionId: Value(sessionId),
      messageType: messageType,
      payload: payload,
      status: 'pending',
      retryCount: const Value(0),
      createdAt: now,
      updatedAt: now,
    );

    return _db.writeTx(() async {
      await _db.into(_db.outboxTable).insert(companion);
      return (await (_db.select(_db.outboxTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<List<OutboxEntry>> getPending() {
    return (_db.select(_db.outboxTable)
          ..where((t) => t.status.equals('pending') | t.status.equals('in_flight'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  @override
  Stream<List<OutboxEntry>> watchPending() {
    return (_db.select(_db.outboxTable)
          ..where((t) => t.status.equals('pending') | t.status.equals('in_flight'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  @override
  Future<bool> updateStatus(String id, String status) {
    return _db.writeTx(() async {
      final item = await (_db.select(_db.outboxTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (item == null) return false;
      return await _db.update(_db.outboxTable).replace(
            item.copyWith(
              status: status,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  @override
  Future<bool> incrementRetry(String id) {
    return _db.writeTx(() async {
      final item = await (_db.select(_db.outboxTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (item == null) return false;
      return await _db.update(_db.outboxTable).replace(
            item.copyWith(
              retryCount: item.retryCount + 1,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  @override
  Future<bool> remove(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.outboxTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }
}
