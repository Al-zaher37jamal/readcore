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
  /// Host accepts only monotonically increasing cumulative totals from LAN.
  Future<ParticipantReadingTime> setTimeAtLeast({required String id,
    required String sessionId, required String deviceId, required int totalSeconds});
  Future<List<ParticipantReadingTime>> getSessionTimes(String sessionId);
  Stream<List<ParticipantReadingTime>> watchSessionTimes(String sessionId);
}

/// The Phase 2 per-device table also holds durable Phase 6 foreground time.
/// Updates are atomic even when the UI queues multiple 15-second intervals.
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
    if (additionalSeconds < 0) {
      throw ArgumentError.value(additionalSeconds, 'additionalSeconds');
    }
    return _db.writeTx(() async {
      // Preserve old row IDs from earlier phases instead of creating a second
      // row when this session was read before the Phase 6 timer was added.
      final existing = await getTime(sessionId, deviceId);
      final rowId = existing?.id ?? id;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await _db.customUpdate('''
INSERT INTO participant_reading_time
  (id, session_id, device_id, total_seconds, last_active_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  total_seconds = participant_reading_time.total_seconds + excluded.total_seconds,
  last_active_at = excluded.last_active_at, updated_at = excluded.updated_at
WHERE participant_reading_time.session_id = excluded.session_id
  AND participant_reading_time.device_id = excluded.device_id
''', variables: [
        Variable.withString(rowId), Variable.withString(sessionId),
        Variable.withString(deviceId), Variable.withInt(additionalSeconds),
        Variable.withInt(now), Variable.withInt(now),
      ], updates: {_db.participantReadingTimeTable});
      return (await (_db.select(_db.participantReadingTimeTable)
          ..where((t) => t.id.equals(rowId))).getSingle());
    });
  }

  @override
  Future<ParticipantReadingTime> setTimeAtLeast({required String id,
      required String sessionId, required String deviceId,
      required int totalSeconds}) async {
    if (totalSeconds < 0 || totalSeconds > 3153600000) {
      throw ArgumentError.value(totalSeconds, 'totalSeconds');
    }
    return _db.writeTx(() async {
      final existing = await getTime(sessionId, deviceId);
      final rowId = existing?.id ?? id;
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      await _db.customUpdate('''
INSERT INTO participant_reading_time
  (id, session_id, device_id, total_seconds, last_active_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  total_seconds = MAX(participant_reading_time.total_seconds, excluded.total_seconds),
  last_active_at = excluded.last_active_at, updated_at = excluded.updated_at
WHERE participant_reading_time.session_id = excluded.session_id
  AND participant_reading_time.device_id = excluded.device_id
''', variables: [Variable.withString(rowId), Variable.withString(sessionId),
        Variable.withString(deviceId), Variable.withInt(totalSeconds),
        Variable.withInt(now), Variable.withInt(now)],
        updates: {_db.participantReadingTimeTable});
      return (await (_db.select(_db.participantReadingTimeTable)
          ..where((t) => t.id.equals(rowId))).getSingle());
    });
  }

  @override
  Future<ParticipantReadingTime?> getTime(String sessionId, String deviceId) =>
      (_db.select(_db.participantReadingTimeTable)..where((t) =>
          t.sessionId.equals(sessionId) & t.deviceId.equals(deviceId)))
          .getSingleOrNull();

  @override
  Future<List<ParticipantReadingTime>> getSessionTimes(String sessionId) =>
      (_db.select(_db.participantReadingTimeTable)..where((t) =>
          t.sessionId.equals(sessionId))).get();

  @override
  Stream<List<ParticipantReadingTime>> watchSessionTimes(String sessionId) =>
      (_db.select(_db.participantReadingTimeTable)..where((t) =>
          t.sessionId.equals(sessionId))).watch();
}
