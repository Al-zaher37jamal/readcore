import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class SessionRepository {
  Future<Session> createSession({
    required String id,
    required String title,
    required String hostDeviceId,
    required String bookId,
    required String status,
  });

  Future<Session?> getSessionById(String id);
  Future<List<Session>> getAllSessions();
  Stream<List<Session>> watchAllSessions();
  Stream<Session?> watchSessionById(String id);
  Future<bool> updateSessionStatus(String id, String status);
  Future<bool> deleteSession(String id);
}

class SessionRepositoryImpl implements SessionRepository {
  final AppDatabase _db;

  SessionRepositoryImpl(this._db);

  @override
  Future<Session> createSession({
    required String id,
    required String title,
    required String hostDeviceId,
    required String bookId,
    required String status,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = SessionsTableCompanion.insert(
      id: id,
      title: title,
      hostDeviceId: hostDeviceId,
      bookId: bookId,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    return _db.writeTx(() async {
      await _db.into(_db.sessionsTable).insert(companion);
      return (await (_db.select(_db.sessionsTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<Session?> getSessionById(String id) {
    return (_db.select(_db.sessionsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<Session>> getAllSessions() {
    return (_db.select(_db.sessionsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  @override
  Stream<List<Session>> watchAllSessions() {
    return (_db.select(_db.sessionsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  @override
  Stream<Session?> watchSessionById(String id) {
    return (_db.select(_db.sessionsTable)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  @override
  Future<bool> updateSessionStatus(String id, String status) {
    return _db.writeTx(() async {
      final session = await getSessionById(id);
      if (session == null) return false;
      return await _db.update(_db.sessionsTable).replace(
            session.copyWith(
              status: status,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  @override
  Future<bool> deleteSession(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.sessionsTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }
}
