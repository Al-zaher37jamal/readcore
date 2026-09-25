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
  /// Called once on cold launch: a prior process is no longer hosting LAN.
  Future<int> recoverInterruptedSessions();
  Future<bool> deleteSession(String id);

  // Phase 6: Session History and Resumable Local Reading
  Future<List<Session>> getSavedSessions();
  Stream<List<Session>> watchSavedSessions();
  Future<bool> saveAndLeaveSession(String id, {int? lastPage, int? totalPages});
  Future<bool> endReadingSession(String id);
  Future<bool> updateSessionLastPage(String id, int currentPage, int totalPages);
  Future<bool> deleteSessionHistoryOnly(String id);
  Future<bool> updateSessionFlags(String id, {bool? timerEnabled, bool? statsEnabled});
  Future<Map<String, dynamic>?> getSessionFlags(String id);
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
      await _db.customStatement(
        'UPDATE sessions SET session_type = ? WHERE id = ?',
        [id.startsWith('solo_') ? 'solo' : 'group', id],
      );
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
    // Lifecycle terminal transitions have their own methods. In particular,
    // a generic LAN/status update must never turn Save & Leave into End.
    if (!const {'created', 'active', 'paused'}.contains(status)) return Future.value(false);
    return _db.writeTx(() async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final changed = await _db.customUpdate(
        "UPDATE sessions SET status = ?, updated_at = ? WHERE id = ? AND status != 'ended'",
        variables: [Variable.withString(status), Variable.withInt(now),
                    Variable.withString(id)],
        updates: {_db.sessionsTable},
      );
      return changed > 0;
    });
  }

  @override
  Future<int> recoverInterruptedSessions() => _db.writeTx(() async {
    // Called only during cold startup, before any Host is created. A process
    // shutdown does not deliver a guaranteed Flutter lifecycle callback; the
    // stale live status must become Saved rather than being misread as Ended.
    // Preserve the actual last activity time instead of stamping launch time.
    final count = await _db.customUpdate('''
UPDATE sessions SET status = 'saved',
  last_activity_at = COALESCE(last_activity_at, updated_at)
WHERE status IN ('active', 'paused', 'created')
''', updates: {_db.sessionsTable});
    if (count > 0) {
      await _db.customUpdate('''
UPDATE session_members SET status = 'disconnected'
WHERE status = 'active' AND session_id IN
  (SELECT id FROM sessions WHERE status = 'saved')
''', updates: {_db.sessionMembersTable});
    }
    return count;
  });

  @override
  Future<bool> deleteSession(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.sessionsTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }

  // Phase 6 implementation

  @override
  Future<List<Session>> getSavedSessions() {
    return (_db.select(_db.sessionsTable)
          ..where((t) => t.status.isIn(['saved', 'ended']))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  @override
  Stream<List<Session>> watchSavedSessions() {
    // Watch all sessions and map to saved/ended
    return (_db.select(_db.sessionsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .map((list) => list.where((s) => s.status == 'saved' || s.status == 'ended').toList());
  }

  @override
  Future<bool> saveAndLeaveSession(String id, {int? lastPage, int? totalPages}) {
    return _db.writeTx(() async {
      // One guarded SQLite write makes status AND page/timestamps durable before
      // the UI may pop. An already-ended room can never be resurrected by Save.
      // Do not replace a stale Drift Session: the generated class may omit
      // migration columns (or overwrite them if regenerated later).
      final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final pageSql = lastPage == null
          ? '' : ', last_page = ?, total_pages = ?';
      final variables = <Variable>[
        Variable.withInt(now), Variable.withInt(now),
        if (lastPage != null) ...[
          Variable.withInt(lastPage), Variable.withInt(totalPages ?? lastPage),
        ],
        Variable.withString(id),
      ];
      final changed = await _db.customUpdate(
        "UPDATE sessions SET status = 'saved', last_activity_at = ?, updated_at = ?"
        "$pageSql WHERE id = ? AND status != 'ended'",
        variables: variables, updates: {_db.sessionsTable},
      );
      return changed > 0;
    });
  }

  @override
  Future<bool> endReadingSession(String id) {
    return _db.writeTx(() async {
      final now = DateTime.now().toUtc();
      final timestamp = now.millisecondsSinceEpoch ~/ 1000;
      // Only an explicit End (or an authoritative Host end received by a
      // participant) writes 'ended'. Save and socket shutdown never do.
      final changed = await _db.customUpdate(
        "UPDATE sessions SET status = 'ended', last_activity_at = ?, "
        "updated_at = ? WHERE id = ? AND status != 'ended'",
        variables: [Variable.withInt(timestamp), Variable.withInt(timestamp),
                    Variable.withString(id)],
        updates: {_db.sessionsTable},
      );
      if (changed == 0) return false;
      await (_db.update(_db.sessionMembersTable)
            ..where((m) => m.sessionId.equals(id) &
                m.role.equals('participant') & m.status.equals('active')))
          .write(SessionMembersTableCompanion(
            status: const Value('left'),
            lastSeenAt: Value(now),
          ));
      return true;
    });
  }

  @override
  Future<bool> updateSessionLastPage(String id, int currentPage, int totalPages) {
    return _db.writeTx(() async {
      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final count = await _db.customUpdate(
        'UPDATE sessions SET last_page = ?, total_pages = ?, last_activity_at = ?, updated_at = ? '
        "WHERE id = ? AND status IN ('created', 'active', 'paused')",
        variables: [
          Variable.withInt(currentPage),
          Variable.withInt(totalPages),
          Variable.withInt(timestamp),
          Variable.withInt(timestamp),
          Variable.withString(id),
        ],
        updates: {_db.sessionsTable},
      );
      return count > 0;
    });
  }

  @override
  Future<bool> deleteSessionHistoryOnly(String id) {
    // Removing a session cascades to its progress, members and events, never to books.
    return _db.writeTx(() async {
      final session = await getSessionById(id);
      if (session == null ||
          (session.status != 'saved' && session.status != 'ended')) return false;
      final count = await (_db.delete(_db.sessionsTable)..where((t) => t.id.equals(id))).go();
      if (count == 0) return false;
      await (_db.delete(_db.kvsTable)
            ..where((t) => t.key.isIn(['session_${id}_timer', 'session_${id}_stats'])))
          .go();
      return true;
    });
  }

  @override
  Future<bool> updateSessionFlags(String id, {bool? timerEnabled, bool? statsEnabled}) {
    return _db.writeTx(() async {
      if (await getSessionById(id) == null) return false;
      final now = DateTime.now().toUtc();
      if (timerEnabled != null) {
        await _db.customStatement(
          'UPDATE sessions SET timer_enabled = ? WHERE id = ?',
          [timerEnabled ? 1 : 0, id],
        );
        await _db.into(_db.kvsTable).insertOnConflictUpdate(KvsTableCompanion.insert(
              key: 'session_${id}_timer',
              value: timerEnabled ? '1' : '0',
              updatedAt: now,
            ));
      }
      if (statsEnabled != null) {
        await _db.customStatement(
          'UPDATE sessions SET stats_enabled = ? WHERE id = ?',
          [statsEnabled ? 1 : 0, id],
        );
        await _db.into(_db.kvsTable).insertOnConflictUpdate(KvsTableCompanion.insert(
              key: 'session_${id}_stats',
              value: statsEnabled ? '1' : '0',
              updatedAt: now,
            ));
      }
      return true;
    });
  }

  @override
  Future<Map<String, dynamic>?> getSessionFlags(String id) async {
    try {
      final rows = await _db.customSelect('SELECT timer_enabled, stats_enabled, session_type FROM sessions WHERE id = ?', variables: [Variable.withString(id)]).get();
      if (rows.isNotEmpty) {
        final data = rows.first.data;
        return {
          'timerEnabled': (data['timer_enabled'] as int? ?? 0) == 1,
          'statsEnabled': (data['stats_enabled'] as int? ?? 0) == 1,
          'sessionType': data['session_type'] as String? ?? 'solo',
        };
      }
    } catch (_) {}
    // Fallback to KVS
    try {
      final timerRows = await _db.customSelect("SELECT value FROM kvs WHERE key = ?", variables: [Variable.withString('session_${id}_timer')]).get();
      final statsRows = await _db.customSelect("SELECT value FROM kvs WHERE key = ?", variables: [Variable.withString('session_${id}_stats')]).get();
      return {
        'timerEnabled': timerRows.isNotEmpty ? timerRows.first.data['value'] == '1' : false,
        'statsEnabled': statsRows.isNotEmpty ? statsRows.first.data['value'] == '1' : false,
        'sessionType': id.startsWith('solo_') ? 'solo' : 'group',
      };
    } catch (_) {
      return {
        'timerEnabled': false,
        'statsEnabled': false,
        'sessionType': id.startsWith('solo_') ? 'solo' : 'group',
      };
    }
  }
}
