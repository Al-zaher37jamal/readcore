import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/features/reading_time/domain/session_reading_timer.dart';

abstract class SessionReadingTimerRepository {
  Future<SessionReadingTimer?> get(String sessionId);
  Stream<SessionReadingTimer?> watch(String sessionId);
  Future<SessionReadingTimer> configure(String sessionId, String actorDeviceId,
      int durationMinutes);
  Future<SessionReadingTimer> start(String sessionId, String actorDeviceId);
  Future<SessionReadingTimer?> finishIfDue(String sessionId);
}

/// Local-first session timer. The sessions row is the authoritative record;
/// participant_reading_time remains the separate elapsed-time statistics.
/// No new networking, background service or per-second database writes.
class SessionReadingTimerRepositoryImpl implements SessionReadingTimerRepository {
  final AppDatabase _db;
  final DateTime Function() _now;

  SessionReadingTimerRepositoryImpl(this._db, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const _select = '''
SELECT id, reading_duration_minutes, reading_started_at, reading_ends_at,
  reading_configured_by_leader_id, reading_timer_status
FROM sessions WHERE id = ?
''';

  SessionReadingTimer _fromRow(Map<String, dynamic> data) {
    DateTime? time(String column) {
      final seconds = data[column] as int?;
      return seconds == null ? null :
          DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
    final status = switch (data['reading_timer_status']) {
      'not_configured' => ReadingTimerStatus.notConfigured,
      'configured' => ReadingTimerStatus.configured,
      'running' => ReadingTimerStatus.running,
      'finished' => ReadingTimerStatus.finished,
      _ => throw StateError('Invalid reading timer state in SQLite'),
    };
    return SessionReadingTimer(
      sessionId: data['id'] as String,
      durationMinutes: data['reading_duration_minutes'] as int?,
      startedAt: time('reading_started_at'),
      endsAt: time('reading_ends_at'),
      configuredByLeaderId: data['reading_configured_by_leader_id'] as String?,
      status: status,
    );
  }

  Future<SessionReadingTimer?> _read(String sessionId) async {
    final row = await _db.customSelect(_select,
      variables: [Variable.withString(sessionId)]).getSingleOrNull();
    return row == null ? null : _fromRow(row.data);
  }

  @override
  Future<SessionReadingTimer?> get(String sessionId) => finishIfDue(sessionId);

  @override
  Stream<SessionReadingTimer?> watch(String sessionId) => _db.customSelect(
    _select, variables: [Variable.withString(sessionId)],
    readsFrom: {_db.sessionsTable},
  ).watch().map((rows) => rows.isEmpty ? null : _fromRow(rows.single.data));

  @override
  Future<SessionReadingTimer> configure(String sessionId, String actorDeviceId,
      int durationMinutes) {
    if (durationMinutes < 1 || durationMinutes > 1440) {
      throw RangeError.range(durationMinutes, 1, 1440, 'durationMinutes');
    }
    if (actorDeviceId.isEmpty) throw StateError('Leader identity is required');
    return _db.writeTx(() async {
      final timestamp = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final changed = await _db.customUpdate('''
UPDATE sessions SET reading_duration_minutes = ?, reading_started_at = NULL,
  reading_ends_at = NULL, reading_configured_by_leader_id = ?,
  reading_timer_status = 'configured', updated_at = ?
WHERE id = ? AND host_device_id = ?
  AND status IN ('created', 'active', 'paused')
  AND reading_timer_status IN ('not_configured', 'configured', 'finished')
''', variables: [Variable.withInt(durationMinutes),
        Variable.withString(actorDeviceId), Variable.withInt(timestamp),
        Variable.withString(sessionId), Variable.withString(actorDeviceId)],
        updates: {_db.sessionsTable});
      if (changed != 1) {
        throw StateError('Only the leader can configure an open, non-running session');
      }
      return (await _read(sessionId))!;
    });
  }

  @override
  Future<SessionReadingTimer> start(String sessionId, String actorDeviceId) {
    if (actorDeviceId.isEmpty) throw StateError('Leader identity is required');
    return _db.writeTx(() async {
      final started = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final changed = await _db.customUpdate('''
UPDATE sessions SET reading_started_at = ?,
  reading_ends_at = ? + reading_duration_minutes * 60,
  reading_timer_status = 'running', updated_at = ?
WHERE id = ? AND host_device_id = ?
  AND reading_configured_by_leader_id = ?
  AND status IN ('created', 'active', 'paused')
  AND reading_timer_status = 'configured'
  AND reading_duration_minutes BETWEEN 1 AND 1440
''', variables: [Variable.withInt(started), Variable.withInt(started),
        Variable.withInt(started), Variable.withString(sessionId),
        Variable.withString(actorDeviceId), Variable.withString(actorDeviceId)],
        updates: {_db.sessionsTable});
      if (changed != 1) {
        throw StateError('Only the leader can start a configured, open session');
      }
      return (await _read(sessionId))!;
    });
  }

  @override
  Future<SessionReadingTimer?> finishIfDue(String sessionId) =>
      _db.writeTx(() async {
        // This is an automatic transition, not a participant editing the
        // duration. It is idempotent and cannot end the reading session.
        await _db.customUpdate('''
UPDATE sessions SET reading_timer_status = 'finished'
WHERE id = ? AND reading_timer_status = 'running'
  AND reading_ends_at <= ?
''', variables: [Variable.withString(sessionId),
          Variable.withInt(_now().toUtc().millisecondsSinceEpoch ~/ 1000)],
          updates: {_db.sessionsTable});
        return _read(sessionId);
      });
}
