import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class SessionMemberRepository {
  Future<SessionMember> addMember({
    required String id,
    required String sessionId,
    required String deviceId,
    required String displayName,
    required String role,
    required String status,
  });

  Future<List<SessionMember>> getMembersBySessionId(String sessionId);
  Stream<List<SessionMember>> watchMembersBySessionId(String sessionId);
  Future<SessionMember?> getMember(String sessionId, String deviceId);
  Future<bool> updateMemberStatus(String id, String status);
  Future<bool> updateLastSeen(String id);
  Future<bool> removeMember(String id);
}

class SessionMemberRepositoryImpl implements SessionMemberRepository {
  final AppDatabase _db;

  SessionMemberRepositoryImpl(this._db);

  @override
  Future<SessionMember> addMember({
    required String id,
    required String sessionId,
    required String deviceId,
    required String displayName,
    required String role,
    required String status,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = SessionMembersTableCompanion.insert(
      id: id,
      sessionId: sessionId,
      deviceId: deviceId,
      displayName: displayName,
      role: role,
      joinedAt: now,
      lastSeenAt: now,
      status: status,
    );

    return _db.writeTx(() async {
      await _db.into(_db.sessionMembersTable).insert(companion);
      return (await (_db.select(_db.sessionMembersTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<List<SessionMember>> getMembersBySessionId(String sessionId) {
    return (_db.select(_db.sessionMembersTable)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  @override
  Stream<List<SessionMember>> watchMembersBySessionId(String sessionId) {
    return (_db.select(_db.sessionMembersTable)..where((t) => t.sessionId.equals(sessionId))).watch();
  }

  @override
  Future<SessionMember?> getMember(String sessionId, String deviceId) {
    return (_db.select(_db.sessionMembersTable)
          ..where((t) => t.sessionId.equals(sessionId) & t.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  @override
  Future<bool> updateMemberStatus(String id, String status) {
    return _db.writeTx(() async {
      final member = await (_db.select(_db.sessionMembersTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (member == null) return false;
      return await _db.update(_db.sessionMembersTable).replace(
            member.copyWith(
              status: status,
              lastSeenAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  @override
  Future<bool> updateLastSeen(String id) {
    return _db.writeTx(() async {
      final member = await (_db.select(_db.sessionMembersTable)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (member == null) return false;
      return await _db.update(_db.sessionMembersTable).replace(
            member.copyWith(
              lastSeenAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  @override
  Future<bool> removeMember(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.sessionMembersTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }
}
