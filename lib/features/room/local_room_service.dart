import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
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
  final BookRepository? _bookRepository;
  final Uuid _uuid;

  LocalRoomService({
    required SessionRepository sessionRepository,
    required SessionMemberRepository sessionMemberRepository,
    required DeviceService deviceService,
    BookRepository? bookRepository,
    Uuid? uuid,
  })  : _sessionRepository = sessionRepository,
        _sessionMemberRepository = sessionMemberRepository,
        _deviceService = deviceService,
        _bookRepository = bookRepository,
        _uuid = uuid ?? const Uuid();

  Future<DeviceProfile> getCurrentProfile() => _deviceService.getOrCreateCurrentProfile();

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
  /// Remote LAN join creates one local copy of the Host's session, then
  /// reuses it on subsequent joins. When the Host advertises the PDF digest,
  /// bind it to this device's matching import (whose UUID may differ).
  Future<Session> joinRoom({
    required String sessionCode,
    String? customDisplayName,
    String? customDeviceId,
    String? remoteTitle,
    String? remoteHostDeviceId,
    String? remoteBookId,
    String? remoteBookSha256,
  }) async {
    final normalizedCode = sessionCode.trim().toUpperCase();
    var session = await _sessionRepository.getSessionById(normalizedCode);
    if (session?.status == 'ended') {
      throw const DatabaseOperationException('Cannot join an ended room session.');
    }
    if (session != null && remoteHostDeviceId != null &&
        session.hostDeviceId != remoteHostDeviceId) {
      throw const DatabaseOperationException('Room code belongs to another Host.');
    }
    // A live remote room must identify its PDF. Without a digest an older
    // Host's snapshot could silently bind this session to books.first.
    if (remoteHostDeviceId != null &&
        (remoteBookSha256 == null || remoteBookSha256.isEmpty)) {
      throw const NotFoundException('Host PDF fingerprint unavailable.');
    }

    // Book IDs are random per import/device. A room's PDF is identified by
    // its digest, not by whichever unrelated book happens to be listed first.
    Book? matchingBook;
    if (remoteBookSha256 != null && remoteBookSha256.isNotEmpty) {
      matchingBook = await _bookRepository?.getBookBySha256(remoteBookSha256);
      if (matchingBook == null) {
        throw const NotFoundException('Import the same PDF as the Host before joining.');
      }
      if (session != null && session.bookId != matchingBook.id) {
        // Old versions chose the first Library book on the participant.
        // Repair that *saved* copy only when the live Host identity matches;
        // never silently attach another Host's room to this history.
        if (session.status != 'saved' ||
            session.hostDeviceId != remoteHostDeviceId ||
            !await _sessionRepository.rebindSavedSessionBook(
                normalizedCode, matchingBook.id)) {
          throw const DatabaseOperationException('This room is linked to a different PDF on this device.');
        }
        session = await _sessionRepository.getSessionById(normalizedCode) ??
            (throw StateError('Saved room disappeared during PDF repair.'));
      }
    }

    if (session == null) {
      // Remote LAN join: session not in local DB, create placeholder
      // Required for 2-device real test: Host creates RM-2936, Participant DB doesn't have it
      if (_bookRepository != null) {
        try {
          final books = await _bookRepository!.getAllBooks();
          if (books.isEmpty) {
            throw NotFoundException('Room with code "$normalizedCode" was not found. Please import a book first.');
          }
          String bookIdToUse = matchingBook?.id ?? books.first.id;
          if (matchingBook == null && remoteBookId != null) {
            final exists = books.any((b) => b.id == remoteBookId);
            if (exists) bookIdToUse = remoteBookId;
          }
          final title = remoteTitle ?? 'Remote Room $normalizedCode';
          final hostId = remoteHostDeviceId ?? 'remote_host_$normalizedCode';

          session = await _sessionRepository.createSession(
            id: normalizedCode,
            title: title,
            hostDeviceId: hostId,
            bookId: bookIdToUse,
            status: 'active',
          );
        } catch (e) {
          if (e is NotFoundException) rethrow;
          throw NotFoundException('Room with code "$normalizedCode" was not found.');
        }
      } else {
        throw NotFoundException('Room with code "$normalizedCode" was not found.');
      }
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

  Future<({int page, int totalPages})?> getSessionPage(String sessionId) =>
      _sessionRepository.getSessionPage(sessionId);

  /// Mirror actual joined Host sockets into the existing member rows. A
  /// reconnect reactivates the same device ID/row; a closed socket is no
  /// longer counted as active, while its membership remains on disk.
  Future<void> syncConnectedParticipants(
      String sessionId, Map<String, String> connected) async {
    final session = await _sessionRepository.getSessionById(sessionId);
    if (session == null || session.status == 'ended') return;
    final members = await _sessionMemberRepository.getMembersBySessionId(sessionId);
    final known = {for (final member in members) member.deviceId: member};
    final activeIds = session.status == 'saved'
        ? <String>{} : connected.keys.toSet();
    for (final id in activeIds) {
      if (id == session.hostDeviceId) continue;
      final member = known[id];
      if (member == null) {
        await _sessionMemberRepository.addMember(
          id: _uuid.v4(), sessionId: sessionId, deviceId: id,
          displayName: connected[id]!, role: 'participant', status: 'active',
        );
      } else if (member.status != 'active') {
        await _sessionMemberRepository.updateMemberStatus(member.id, 'active');
      }
    }
    for (final member in members) {
      if (member.role != 'host' && member.status == 'active' &&
          !activeIds.contains(member.deviceId)) {
        await _sessionMemberRepository.updateMemberStatus(member.id, 'disconnected');
      }
    }
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

  /// Saves this device's room history without ending the shared reading session.
  Future<bool> saveAndLeaveSession(String sessionId, {int? lastPage, int? totalPages}) {
    return _sessionRepository.saveAndLeaveSession(
      sessionId,
      lastPage: lastPage,
      totalPages: totalPages,
    );
  }

  /// Ends the reading session permanently and marks all members as left/not active.
  Future<bool> endSession(String sessionId) async {
    final success = await _sessionRepository.endReadingSession(sessionId);
    if (success) {
      try {
        final members = await _sessionMemberRepository.getMembersBySessionId(sessionId);
        for (final m in members) {
          if (m.status == 'active') {
            if (m.role != 'host') {
              await _sessionMemberRepository.updateMemberStatus(m.id, 'left');
            }
          }
        }
      } catch (_) {}
    }
    return success;
  }

  /// Marks all members as left when session ends – used for strict consistency (optional)
  Future<void> endSessionAndClearParticipants(String sessionId) async {
    await _sessionRepository.endReadingSession(sessionId);
    try {
      final members = await _sessionMemberRepository.getMembersBySessionId(sessionId);
      for (final m in members) {
        if (m.role != 'host' && m.status == 'active') {
          await _sessionMemberRepository.updateMemberStatus(m.id, 'left');
        }
      }
    } catch (_) {}
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
