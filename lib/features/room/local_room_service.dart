import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/profile/device_service.dart';

/// Representation of a room's state including its active session, participant list,
/// and whether the local user has the host role.
class RoomDetails {
  final Session session;
  final List<SessionMember> members;
  final bool isHost;

  const RoomDetails({
    required this.session,
    required this.members,
    required this.isHost,
  });

  int get activeParticipantCount =>
      members.where((m) => m.status == 'active').length;
}

/// Service managing the local reading room lifecycle, session codes, and participant roles.
class LocalRoomService {
  final SessionRepository _sessionRepository;
  final SessionMemberRepository _sessionMemberRepository;
  final DeviceService _deviceService;
  final Uuid _uuid;

  LocalRoomService({
    required SessionRepository sessionRepository,
    required SessionMemberRepository sessionMemberRepository,
    required DeviceService deviceService,
    Uuid? uuid,
  })  : _sessionRepository = sessionRepository,
        _sessionMemberRepository = sessionMemberRepository,
        _deviceService = deviceService,
        _uuid = uuid ?? const Uuid();

  /// Generates a simple, human-friendly 6-character session code (e.g. "RM-4821").
  String generateSessionCode() {
    final random = Random();
    final number = 1000 + random.nextInt(9000);
    return 'RM-$number';
  }

  /// Creates a new local reading room with the current user as Host.
  Future<Session> createRoom({
    required String title,
    required String bookId,
    String? customSessionCode,
  }) async {
    final sessionCode = customSessionCode ?? generateSessionCode();
    final profile = await _deviceService.getOrCreateCurrentProfile();

    // 1. Create the session in SQLite
    final session = await _sessionRepository.createSession(
      id: sessionCode,
      title: title,
      hostDeviceId: profile.id,
      bookId: bookId,
      status: 'created',
    );

    // 2. Add the creator as Host in session_members
    await _sessionMemberRepository.addMember(
      id: _uuid.v4(),
      sessionId: sessionCode,
      deviceId: profile.id,
      displayName: profile.displayName,
      role: 'host',
      status: 'active',
    );

    return session;
  }

  /// Joins an existing reading room using its session code.
  Future<Session> joinRoom({
    required String sessionCode,
    String? customDisplayName,
    String? customDeviceId,
  }) async {
    final normalizedCode = sessionCode.trim().toUpperCase();
    final session = await _sessionRepository.getSessionById(normalizedCode);

    if (session == null) {
      throw NotFoundException('Room with code "$normalizedCode" was not found.');
    }

    if (session.status == 'ended') {
      throw const DatabaseOperationException('Cannot join an ended room session.');
    }

    final profile = await _deviceService.getOrCreateCurrentProfile();
    final deviceId = customDeviceId ?? profile.id;
    final displayName = customDisplayName ?? profile.displayName;

    final existingMember = await _sessionMemberRepository.getMember(
      normalizedCode,
      deviceId,
    );

    if (existingMember != null) {
      // Re-activate member if already known
      await _sessionMemberRepository.updateMemberStatus(existingMember.id, 'active');
      await _sessionMemberRepository.updateLastSeen(existingMember.id);
    } else {
      // Add as participant
      final role = (deviceId == session.hostDeviceId) ? 'host' : 'participant';
      await _sessionMemberRepository.addMember(
        id: _uuid.v4(),
        sessionId: normalizedCode,
        deviceId: deviceId,
        displayName: displayName,
        role: role,
        status: 'active',
      );
    }

    return session;
  }

  /// Starts the reading session, setting status to 'active'.
  Future<bool> startSession(String sessionId) async {
    return _sessionRepository.updateSessionStatus(sessionId, 'active');
  }

  /// Pauses the reading session.
  Future<bool> pauseSession(String sessionId) async {
    return _sessionRepository.updateSessionStatus(sessionId, 'paused');
  }

  /// Resumes the reading session.
  Future<bool> resumeSession(String sessionId) async {
    return _sessionRepository.updateSessionStatus(sessionId, 'active');
  }

  /// Ends the reading session permanently.
  Future<bool> endSession(String sessionId) async {
    return _sessionRepository.updateSessionStatus(sessionId, 'ended');
  }

  /// Leaves the current room session.
  Future<void> leaveRoom(String sessionId, [String? customDeviceId]) async {
    final profile = await _deviceService.getOrCreateCurrentProfile();
    final deviceId = customDeviceId ?? profile.id;

    final member = await _sessionMemberRepository.getMember(sessionId, deviceId);
    if (member != null) {
      await _sessionMemberRepository.updateMemberStatus(member.id, 'left');
    }
  }

  /// Fetches complete room details including participant list and host determination.
  Future<RoomDetails?> getRoomDetails(String sessionId) async {
    final session = await _sessionRepository.getSessionById(sessionId);
    if (session == null) return null;

    final members = await _sessionMemberRepository.getMembersBySessionId(sessionId);
    final profile = await _deviceService.getOrCreateCurrentProfile();
    final isHost = session.hostDeviceId == profile.id;

    return RoomDetails(
      session: session,
      members: members,
      isHost: isHost,
    );
  }

  /// Reactive stream of session details.
  Stream<Session?> watchRoom(String sessionId) {
    return _sessionRepository.watchSessionById(sessionId);
  }

  /// Reactive stream of members in a room.
  Stream<List<SessionMember>> watchRoomMembers(String sessionId) {
    return _sessionMemberRepository.watchMembersBySessionId(sessionId);
  }
}
