import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class SessionEventRepository {
  Future<SessionEvent> recordEvent({
    required String id,
    required String sessionId,
    required String deviceId,
    required String eventType,
    required String payload,
    required int sequenceNumber,
  });

  Future<List<SessionEvent>> getEvents(String sessionId, {int afterSequence = 0});
  Stream<List<SessionEvent>> watchEvents(String sessionId);
  Future<int> getNextSequenceNumber(String sessionId);
}

class SessionEventRepositoryImpl implements SessionEventRepository {
  final AppDatabase _db;

  SessionEventRepositoryImpl(this._db);

  @override
  Future<SessionEvent> recordEvent({
    required String id,
    required String sessionId,
    required String deviceId,
    required String eventType,
    required String payload,
    required int sequenceNumber,
  }) async {
    final companion = SessionEventsTableCompanion.insert(
      id: id,
      sessionId: sessionId,
      deviceId: deviceId,
      eventType: eventType,
      payload: payload,
      sequenceNumber: sequenceNumber,
      createdAt: DateTime.now().toUtc(),
    );

    return _db.writeTx(() async {
      await _db.into(_db.sessionEventsTable).insert(companion);
      return (await (_db.select(_db.sessionEventsTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<List<SessionEvent>> getEvents(String sessionId, {int afterSequence = 0}) {
    return (_db.select(_db.sessionEventsTable)
          ..where((t) => t.sessionId.equals(sessionId) & t.sequenceNumber.isBiggerThanValue(afterSequence))
          ..orderBy([(t) => OrderingTerm.asc(t.sequenceNumber)]))
        .get();
  }

  @override
  Stream<List<SessionEvent>> watchEvents(String sessionId) {
    return (_db.select(_db.sessionEventsTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sequenceNumber)]))
        .watch();
  }

  @override
  Future<int> getNextSequenceNumber(String sessionId) async {
    final query = _db.selectOnly(_db.sessionEventsTable)
      ..addColumns([_db.sessionEventsTable.sequenceNumber.max()])
      ..where(_db.sessionEventsTable.sessionId.equals(sessionId));
    final result = await query.getSingleOrNull();
    final maxSeq = result?.read(_db.sessionEventsTable.sequenceNumber.max());
    return (maxSeq ?? 0) + 1;
  }
}
