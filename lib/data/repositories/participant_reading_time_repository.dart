import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class ParticipantReadingTimeRepository {
  Future<ParticipantReadingTime> addReadingTime({
    required String id,
    required String sessionId,
    required String deviceId,
    required int additionalSeconds,
  });

  Future<ParticipantReadingTime?> getTime(String sessionId, String deviceId);
  Future<List<ParticipantReadingTime>> getSessionTimes(String sessionId);
  Stream<List<ParticipantReadingTime>> watchSessionTimes(String sessionId);
}

class ParticipantReadingTimeRepositoryImpl implements ParticipantReadingTimeRepository {
  final AppDatabase _db;

  ParticipantReadingTimeRepositoryImpl(this._db);

  @override
  Future<ParticipantReadingTime> addReadingTime({
    required String id,
    required String sessionId,
    required String deviceId,
    required int additionalSeconds,
  }) async {
    final now = DateTime.now().toUtc();
    return _db.writeTx(() async {
      final existing = await (_db.select(_db.participantReadingTimeTable)
            ..where((t) => t.sessionId.equals(sessionId) & t.deviceId.equals(deviceId)))
          .getSingleOrNull();

      if (existing == null) {
        final companion = ParticipantReadingTimeTableCompanion.insert(
          id: id,
          sessionId: sessionId,
          deviceId: deviceId,
          totalSeconds: Value(additionalSeconds),
          lastActiveAt: now,
          updatedAt: now,
        );
        await _db.into(_db.participantReadingTimeTable).insert(companion);
        return (await (_db.select(_db.participantReadingTimeTable)..where((t) => t.id.equals(id))).getSingle());
      } else {
        final updated = existing.copyWith(
          totalSeconds: existing.totalSeconds + additionalSeconds,
          lastActiveAt: now,
          updatedAt: now,
        );
        await _db.update(_db.participantReadingTimeTable).replace(updated);
        return updated;
      }
    });
  }

  @override
  Future<ParticipantReadingTime?> getTime(String sessionId, String deviceId) {
    return (_db.select(_db.participantReadingTimeTable)
          ..where((t) => t.sessionId.equals(sessionId) & t.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  @override
  Future<List<ParticipantReadingTime>> getSessionTimes(String sessionId) {
    return (_db.select(_db.participantReadingTimeTable)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  @override
  Stream<List<ParticipantReadingTime>> watchSessionTimes(String sessionId) {
    return (_db.select(_db.participantReadingTimeTable)..where((t) => t.sessionId.equals(sessionId))).watch();
  }
}
