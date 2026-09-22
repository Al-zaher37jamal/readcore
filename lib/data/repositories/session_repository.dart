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

  // Phase 6 implementation

  @override
  Future<List<Session>> getSavedSessions() async {
    // Saved = status in ('saved', 'ended', 'active', 'paused') but we want history: saved and ended are primary
    // For My Sessions, show saved and ended, ordered by updatedAt desc (last activity)
    final query = _db.select(_db.sessionsTable)
      ..where((t) => t.status.equals('saved') | t.status.equals('ended') | t.status.equals('active') | t.status.equals('paused') | t.status.equals('created'))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final all = await query.get();
    // Filter out solo_ prefix? We include all, but rooms_screen filters solo_ out. For My Sessions, include solo and group saved.
    return all.where((s) => s.status == 'saved' || s.status == 'ended').toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
  Future<bool> saveAndLeaveSession(String id, {int? lastPage, int? totalPages}) async {
    return _db.writeTx(() async {
      final session = await getSessionById(id);
      if (session == null) return false;
      // Update status to saved, updatedAt = now, and try to update new columns via raw SQL if they exist
      final now = DateTime.now().toUtc();
      await _db.customStatement(
        'UPDATE sessions SET status = ?, updated_at = ? WHERE id = ?',
        [ 'saved', now.millisecondsSinceEpoch, id ],
      );
      // If new columns exist, update them
      if (lastPage != null) {
        try {
          await _db.customStatement('UPDATE sessions SET last_page = ?, total_pages = ?, last_activity_at = ? WHERE id = ?', [lastPage, totalPages ?? lastPage, now.millisecondsSinceEpoch, id]);
        } catch (_) {}
      } else {
        try {
          await _db.customStatement('UPDATE sessions SET last_activity_at = ? WHERE id = ?', [now.millisecondsSinceEpoch, id]);
        } catch (_) {}
      }
      // Also update via Drift replace for updatedAt
      final updated = await getSessionById(id);
      if (updated != null) {
        await _db.update(_db.sessionsTable).replace(updated.copyWith(status: 'saved', updatedAt: now));
      }
      return true;
    });
  }

  @override
  Future<bool> endReadingSession(String id) async {
    return _db.writeTx(() async {
      final session = await getSessionById(id);
      if (session == null) return false;
      final now = DateTime.now().toUtc();
      await _db.customStatement(
        'UPDATE sessions SET status = ?, updated_at = ? WHERE id = ?',
        ['ended', now.millisecondsSinceEpoch, id],
      );
      try {
        await _db.customStatement('UPDATE sessions SET last_activity_at = ? WHERE id = ?', [now.millisecondsSinceEpoch, id]);
      } catch (_) {}
      final updated = await getSessionById(id);
      if (updated != null) {
        await _db.update(_db.sessionsTable).replace(updated.copyWith(status: 'ended', updatedAt: now));
      }
      return true;
    });
  }

  @override
  Future<bool> updateSessionLastPage(String id, int currentPage, int totalPages) async {
    try {
      final now = DateTime.now().toUtc();
      await _db.customStatement(
        'UPDATE sessions SET last_page = ?, total_pages = ?, last_activity_at = ?, updated_at = ? WHERE id = ?',
        [currentPage, totalPages, now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, id],
      );
    } catch (_) {
      // If columns don't exist, just update updatedAt via Drift
      final session = await getSessionById(id);
      if (session != null) {
        await _db.update(_db.sessionsTable).replace(session.copyWith(updatedAt: DateTime.now().toUtc()));
      }
    }
    return true;
  }

  @override
  Future<bool> deleteSessionHistoryOnly(String id) async {
    // Deletes session record, metadata, events only, keeps book file and library entry
    // ON DELETE CASCADE will remove members, events, progress, etc., but not books
    return deleteSession(id);
  }

  @override
  Future<bool> updateSessionFlags(String id, {bool? timerEnabled, bool? statsEnabled}) async {
    try {
      if (timerEnabled != null) {
        await _db.customStatement('UPDATE sessions SET timer_enabled = ? WHERE id = ?', [timerEnabled ? 1 : 0, id]);
      }
      if (statsEnabled != null) {
        await _db.customStatement('UPDATE sessions SET stats_enabled = ? WHERE id = ?', [statsEnabled ? 1 : 0, id]);
      }
      // Also store in KVS as fallback for when columns don't exist
      if (timerEnabled != null) {
        await _db.customStatement("INSERT OR REPLACE INTO kvs (key, value, updated_at) VALUES (?, ?, ?)", ['session_${id}_timer', timerEnabled ? '1' : '0', DateTime.now().toUtc().millisecondsSinceEpoch]);
      }
      if (statsEnabled != null) {
        await _db.customStatement("INSERT OR REPLACE INTO kvs (key, value, updated_at) VALUES (?, ?, ?)", ['session_${id}_stats', statsEnabled ? '1' : '0', DateTime.now().toUtc().millisecondsSinceEpoch]);
      }
    } catch (_) {}
    return true;
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
