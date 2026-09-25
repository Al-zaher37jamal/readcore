import 'dart:async';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'lan_connection_state.dart';
import 'lan_host_server.dart';
import 'lan_participant_client.dart';

/// Coordinates reading synchronization between LAN sockets and the local SQLite database.
class LanSyncCoordinator {
  final String sessionId;
  final String bookId;
  final String deviceId;
  final String displayName;
  final bool isHost;

  final ReadingProgressRepository _progressRepo;
  final SessionRepository _sessionRepo;

  LanHostServer? _hostServer;
  LanParticipantClient? _participantClient;

  StreamSubscription<int>? _participantPageSub;
  StreamSubscription<String>? _participantStatusSub;

  int _currentPage = 1;
  int _totalPages = 1;

  LanSyncCoordinator({
    required this.sessionId,
    required this.bookId,
    required this.deviceId,
    required this.displayName,
    required this.isHost,
    required ReadingProgressRepository readingProgressRepository,
    required SessionRepository sessionRepository,
    int initialPage = 1,
    int totalPages = 1,
  })  : _progressRepo = readingProgressRepository,
        _sessionRepo = sessionRepository,
        _currentPage = initialPage,
        _totalPages = totalPages;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  LanHostServer? get hostServer => _hostServer;
  LanParticipantClient? get participantClient => _participantClient;

  /// Stream of connection state for the local device.
  Stream<LanConnectionState> get connectionStateStream {
    if (isHost) {
      return Stream.value(
        _hostServer?.isRunning == true
            ? LanConnectionState.connected
            : LanConnectionState.disconnected,
      );
    } else {
      return _participantClient?.stateStream ??
          Stream.value(LanConnectionState.disconnected);
    }
  }

  /// Stream of synchronized page updates.
  Stream<int> get pageStream {
    if (isHost) {
      return const Stream.empty();
    } else {
      return _participantClient?.pageStream ?? const Stream.empty();
    }
  }

  /// Stream of session status updates.
  Stream<String> get statusStream {
    if (isHost) {
      return const Stream.empty();
    } else {
      return _participantClient?.statusStream ?? const Stream.empty();
    }
  }

  /// Starts Host server on this device.
  Future<void> startHost({int port = 40404}) async {
    if (!isHost) return;

    _hostServer = LanHostServer(
      sessionId: sessionId,
      hostDeviceId: deviceId,
      hostDisplayName: displayName,
      initialPage: _currentPage,
      totalPages: _totalPages,
      requestedPort: port,
    );

    await _hostServer!.start();
  }

  /// Connects Participant client to Host device.
  Future<void> connectParticipant({
    required String hostAddress,
    required int port,
  }) async {
    if (isHost) return;

    _participantClient = LanParticipantClient(
      sessionId: sessionId,
      deviceId: deviceId,
      displayName: displayName,
      autoReconnect: true,
    );

    // Listen to authoritative page changes from Host and persist into SQLite
    _participantPageSub = _participantClient!.pageStream.listen((page) async {
      _currentPage = page;
      await _persistParticipantProgress(page);
    });

    // Preserve the distinction between Host Save and End on this device too.
    _participantStatusSub = _participantClient!.statusStream.listen((status) async {
      if (status == 'saved') {
        await _sessionRepo.saveAndLeaveSession(sessionId,
            lastPage: _participantClient?.currentPage,
            totalPages: _participantClient?.totalPages);
      } else if (status == 'ended') {
        await _sessionRepo.endReadingSession(sessionId);
      } else {
        await _sessionRepo.updateSessionStatus(sessionId, status);
      }
    });

    await _participantClient!.connect(hostAddress: hostAddress, port: port);
  }

  /// Host action: changes page, updates SQLite, and broadcasts to participants.
  Future<void> hostChangePage(int newPage, [int? totalPages]) async {
    if (!isHost) return;

    _currentPage = newPage;
    if (totalPages != null) _totalPages = totalPages;

    // 1. Persist Host's progress to SQLite
    final progressId = 'prog_${sessionId}_${bookId}_$deviceId';
    await _progressRepo.updateProgress(
      id: progressId,
      sessionId: sessionId,
      bookId: bookId,
      deviceId: deviceId,
      currentPage: newPage,
      totalPages: _totalPages,
    );

    // 2. Broadcast to all LAN participants
    _hostServer?.broadcastPageChange(newPage, _totalPages);
  }

  /// Host action: starts session.
  Future<void> hostStartSession() async {
    if (!isHost) return;
    await _sessionRepo.updateSessionStatus(sessionId, 'active');
    _hostServer?.broadcastSessionStarted();
  }

  /// Host action: pauses session.
  Future<void> hostPauseSession() async {
    if (!isHost) return;
    await _sessionRepo.updateSessionStatus(sessionId, 'paused');
    _hostServer?.broadcastSessionPaused();
  }

  /// Host action: resumes session.
  Future<void> hostResumeSession() async {
    if (!isHost) return;
    await _sessionRepo.updateSessionStatus(sessionId, 'active');
    _hostServer?.broadcastSessionResumed();
  }

  /// Host action: ends session.
  Future<void> hostEndSession() async {
    if (!isHost) return;
    if (await _sessionRepo.endReadingSession(sessionId)) {
      _hostServer?.broadcastSessionEnded();
    }
  }

  /// Persists participant's synchronized page to SQLite.
  Future<void> _persistParticipantProgress(int page) async {
    final progressId = 'prog_${sessionId}_${bookId}_$deviceId';
    await _progressRepo.updateProgress(
      id: progressId,
      sessionId: sessionId,
      bookId: bookId,
      deviceId: deviceId,
      currentPage: page,
      totalPages: _totalPages,
    );
  }

  /// Clean shutdown of server or client sockets.
  Future<void> stop() async {
    _participantPageSub?.cancel();
    _participantStatusSub?.cancel();

    if (_hostServer != null) {
      await _hostServer!.stop();
      _hostServer!.dispose();
      _hostServer = null;
    }

    if (_participantClient != null) {
      await _participantClient!.disconnect();
      _participantClient!.dispose();
      _participantClient = null;
    }
  }
}
