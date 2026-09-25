import 'dart:async';
import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:flutter/services.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'package:readmesh/features/session_content/app_sharing_service.dart';
import 'package:readmesh/features/lan/lan_connection_state.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/lan/lan_ip_helper.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import 'package:readmesh/features/room/local_room_service.dart';

/// Screen displaying the active room details, participant roster, host controls,
/// LAN connection state, and entrance to the room's synchronized reading experience.
/// FIXED: LAN IP discovery real, connected count consistency, participant status after End, RTL, localization.
class RoomDetailScreen extends StatefulWidget {
  final String sessionId;
  final String? hostAddress;
  final int? port;
  /// Only My Sessions -> Resume may restart this previously saved Host room.
  final bool resumeSavedSession;
  final LocalRoomService? roomService;
  final BookRepository? bookRepository;
  final ReadingProgressRepository? progressRepository;
  final ParticipantReadingTimeRepository? readingTimeRepository;
  final DeviceService? deviceService;
  final LanHostServer? hostServer;
  final LanParticipantClient? participantClient;
  final LanDiscoveryService? discoveryService;
  final SessionContentRepository? contentRepository;
  final SessionVoiceStore? voiceStore;

  const RoomDetailScreen({
    super.key,
    required this.sessionId,
    this.hostAddress,
    this.port,
    this.resumeSavedSession = false,
    this.roomService,
    this.bookRepository,
    this.progressRepository,
    this.readingTimeRepository,
    this.deviceService,
    this.hostServer,
    this.participantClient,
    this.discoveryService,
    this.contentRepository,
    this.voiceStore,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late final LocalRoomService _roomService;
  late final BookRepository _bookRepo;
  ReadingProgressRepository? _progressRepo;
  ParticipantReadingTimeRepository? _readingTimeRepo;
  late final DeviceService _deviceService;
  late final LanDiscoveryService _discoveryService;
  late final Stream<Session?> _sessionStream;
  late final Stream<List<SessionMember>> _membersStream;
  DeviceProfile? _currentProfile;

  LanHostServer? _hostServer;
  LanParticipantClient? _participantClient;
  SessionContentSync? _contentSync;
  StreamSubscription<LanConnectionState>? _participantConnSub;
  StreamSubscription<List<LanConnectedParticipant>>? _hostParticipantsSub;
  StreamSubscription<String>? _participantStatusSub;
  bool _exitApproved = false;
  bool _closingRoom = false;
  bool _exitDialogOpen = false;

  LanConnectionState _participantState = LanConnectionState.disconnected;
  String _hostDisplayIp = ''; // Fixed: no default 127.0.0.1, show loading then real IP
  int _hostPort = 40404;
  int _lanConnectedCount = 0;
  String _sessionStatusForParticipant = 'created';

  @override
  void initState() {
    super.initState();
    _roomService = widget.roomService ?? getIt<LocalRoomService>();
    _bookRepo = widget.bookRepository ?? getIt<BookRepository>();
    _progressRepo = widget.progressRepository ??
        (getIt.isRegistered<ReadingProgressRepository>()
            ? getIt<ReadingProgressRepository>() : null);
    _readingTimeRepo = widget.readingTimeRepository ??
        (getIt.isRegistered<ParticipantReadingTimeRepository>()
            ? getIt<ParticipantReadingTimeRepository>() : null);
    _deviceService = widget.deviceService ?? getIt<DeviceService>();
    _discoveryService = widget.discoveryService ??
        (getIt.isRegistered<LanDiscoveryService>() ? getIt<LanDiscoveryService>() : LanDiscoveryService());
    _sessionStream = _roomService.watchRoom(widget.sessionId);
    _membersStream = _roomService.watchRoomMembers(widget.sessionId);
    _currentProfile = _deviceService.cachedProfile;

    _hostServer = widget.hostServer;
    _participantClient = widget.participantClient;

    if (_currentProfile == null) {
      _loadProfile();
    } else {
      _initLan();
    }

    // The displayed connected count comes from live TCP sockets, not stale
    // session_members rows (which are local to each phone).
  }

  Future<void> _loadProfile() async {
    final profile = await _deviceService.getOrCreateCurrentProfile();
    if (mounted) {
      setState(() {
        _currentProfile = profile;
      });
      _initLan();
    }
  }

  Future<void> _initLan() async {
    if (_currentProfile == null) return;
    final session = await _roomService.watchRoom(widget.sessionId).first;
    if (!mounted || session == null || session.status == 'ended') return;
    final isHost = session.hostDeviceId == _currentProfile!.id;

    if (isHost) {
      final wasSaved = session.status == 'saved';
      // Opening saved history is not itself Resume. Only My Sessions may
      // restart this same room; do not mark it active until TCP has bound.
      if (wasSaved && !widget.resumeSavedSession) return;
      var activatedSavedSession = false;
      try {
        if (_hostServer == null) {
          final book = await _bookRepo.getBookById(session.bookId);
          final progress = await _progressRepo?.getProgress(session.id, _currentProfile!.id);
          if (!mounted) return;
          final pages = book?.pageCount ?? progress?.totalPages ?? 1;
          final total = pages > 0 ? pages : 1;
          _hostServer = LanHostServer(
            sessionId: widget.sessionId,
            hostDeviceId: _currentProfile!.id,
            hostDisplayName: _currentProfile!.displayName,
            initialPage: (progress?.currentPage ?? 1).clamp(1, total),
            totalPages: total,
            // The fresh socket can accept joins only after SQLite is active;
            // the beacon is published below, after the DB transition.
            sessionStatus: wasSaved ? 'active' : session.status,
            requestedPort: widget.port ?? 40404,
          );
        }
        if (!_hostServer!.isRunning) {
          await _hostServer!.start(); // TCP 40404, bind all LAN interfaces
        }
        if (!mounted) throw StateError('Room closed during resume.');
        if (wasSaved) {
          if (!await _roomService.resumeSession(widget.sessionId)) {
            throw StateError('Saved room could not be resumed.');
          }
          activatedSavedSession = true;
        }
        // A recovered Host/member becomes active under its existing identity.
        await _roomService.joinRoom(sessionCode: widget.sessionId);
        if (!mounted) throw StateError('Room closed during resume.');
        await _attachContentSync(session, isHost: true);
        if (!mounted) throw StateError('Room closed during resume.');
      } catch (e) {
        // Never advertise a ghost active room when TCP or reactivation fails.
        Object? rollbackError;
        try {
          if (activatedSavedSession &&
              !await _roomService.saveAndLeaveSession(widget.sessionId)) {
            throw StateError('Unable to restore saved room after failed resume.');
          }
        } catch (error) {
          rollbackError = error;
        } finally {
          await _hostServer?.stop();
          if (widget.hostServer == null) _hostServer?.dispose();
          _hostServer = null;
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rollbackError == null
              ? '$e' : '$e; rollback failed: $rollbackError'),
              backgroundColor: Colors.red),
        );
        return;
      }
      setState(() {
        _hostDisplayIp = _hostServer!.localIp;
        _hostPort = _hostServer!.port;
        _lanConnectedCount = _hostServer!.connectedClientCount;
      });
      if (_hostServer!.isRunning && !LanIpHelper.isLoopback(_hostDisplayIp)) {
        _discoveryService.startBeacon(
          sessionId: widget.sessionId,
          title: session.title,
          hostIp: _hostDisplayIp,
          port: _hostPort,
        ); // UDP 40405; manual IP remains available when UDP is blocked.
      }
      _hostParticipantsSub = _hostServer!.participantsStream.listen((list) {
        if (mounted) setState(() => _lanConnectedCount = list.length);
      });
    } else {
      if (widget.hostAddress == null && _participantClient == null) return;
      _participantClient ??= LanParticipantClient(
        sessionId: widget.sessionId,
        deviceId: _currentProfile!.id,
        displayName: _currentProfile!.displayName,
      );
      final client = _participantClient!;
      _participantConnSub = client.stateStream.listen((state) {
        if (mounted) setState(() => _participantState = state);
      });
      _participantStatusSub = client.statusStream.listen(_handleParticipantStatus);
      await _attachContentSync(session, isHost: false);
      if (!mounted) return;
      if (client.hasSnapshot) _handleParticipantStatus(client.sessionStatus);
      if (widget.hostAddress != null && !client.isConnected) {
        try {
          await client.connect(
            hostAddress: widget.hostAddress!,
            port: widget.port ?? 40404,
          );
        } catch (e) {
          if (mounted) {
            setState(() => _participantState = LanConnectionState.disconnected);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${AppLocalizations.of(context).joinFailed}: $e'),
              backgroundColor: Colors.red,
            ));
          }
        }
      }
    }
  }

  Future<void> _attachContentSync(Session session, {required bool isHost}) async {
    if (_contentSync != null) return;
    final content = widget.contentRepository ??
        (getIt.isRegistered<SessionContentRepository>()
            ? getIt<SessionContentRepository>() : null);
    final files = widget.voiceStore ??
        (getIt.isRegistered<SessionVoiceStore>() ? getIt<SessionVoiceStore>() : null);
    if (content == null || files == null) return;
    final book = await _bookRepo.getBookById(session.bookId);
    if (!mounted || _currentProfile == null) return;
    _contentSync = SessionContentSync(
      sessionId: session.id, bookId: session.bookId,
      deviceId: _currentProfile!.id, displayName: _currentProfile!.displayName,
      totalPages: book?.pageCount ?? 1,
      repository: content, voiceStore: files,
      progressRepository: _progressRepo,
      readingTimeRepository: _readingTimeRepo,
      host: isHost ? _hostServer : null,
      participant: isHost ? null : _participantClient,
    )..start();
  }

  Future<void> _handleParticipantStatus(String status) async {
    if (mounted) setState(() => _sessionStatusForParticipant = status);
    try {
      if (status == 'ended') {
        await _roomService.endSession(widget.sessionId);
      } else if (status == 'saved') {
        await _roomService.saveAndLeaveSession(
          widget.sessionId,
          lastPage: _participantClient?.currentPage,
          totalPages: _participantClient?.totalPages,
        );
        await _roomService.leaveRoom(widget.sessionId);
      } else if (status == 'paused') {
        await _roomService.pauseSession(widget.sessionId);
      } else if (status == 'active') {
        // A returning participant had been marked 'left' when the old LAN
        // connection was saved; the fresh Host snapshot reactivates that role.
        await _roomService.joinRoom(sessionCode: widget.sessionId);
        await _roomService.startSession(widget.sessionId);
      }
      if (status == 'ended' || status == 'saved') {
        await _participantClient?.disconnect();
        if (mounted) setState(() => _participantState = LanConnectionState.disconnected);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _participantConnSub?.cancel();
    _hostParticipantsSub?.cancel();
    _participantStatusSub?.cancel();
    if (_contentSync != null) unawaited(_contentSync!.dispose());
    if (widget.hostServer == null) {
      _hostServer?.stop();
      _hostServer?.dispose();
    }
    if (widget.participantClient == null) {
      _participantClient?.disconnect();
      _participantClient?.dispose();
    }
    _discoveryService.stopBeacon();
    super.dispose();
  }

  Future<void> _promptRoomExit() async {
    if (_closingRoom || _exitDialogOpen) return;
    _exitDialogOpen = true;
    try {
      final details = await _roomService.getRoomDetails(widget.sessionId);
      if (!mounted) return;
      if (details == null || !details.isHost ||
          details.session.status == 'saved' || details.session.status == 'ended') {
        await _leaveRoomDetail();
        return;
      }
      final l10n = AppLocalizations.of(context);
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('room_leave_dialog'),
          title: Text(l10n.whatWouldYouDo),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            TextButton(
              key: const Key('room_save_and_leave_button'),
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(l10n.saveAndLeave),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'end'),
              child: Text(l10n.endReadingSession),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'save') {
        await _leaveRoomDetail();
      } else if (choice == 'end') {
        await _endRoom(widget.sessionId);
        final latest = await _roomService.getRoomDetails(widget.sessionId);
        if (mounted && latest?.session.status == 'ended') {
          await _leaveRoomDetail();
        }
      }
    } finally {
      _exitDialogOpen = false;
    }
  }

  Future<void> _leaveRoomDetail() async {
    if (_closingRoom) return;
    _closingRoom = true;
    try {
      final details = await _roomService.getRoomDetails(widget.sessionId);
      if (details != null &&
          details.session.status != 'saved' && details.session.status != 'ended') {
        if (details.isHost) {
          final saved = await _roomService.saveAndLeaveSession(
            widget.sessionId,
            lastPage: _hostServer?.currentPage,
            totalPages: _hostServer?.totalPages,
          );
          if (!saved) throw StateError('Unable to save room history.');
          _discoveryService.stopBeacon();
          _hostServer?.broadcastSessionSaved();
          await _hostServer?.stop();
        } else {
          final saved = await _roomService.saveAndLeaveSession(
            widget.sessionId,
            lastPage: _participantClient?.currentPage,
            totalPages: _participantClient?.totalPages,
          );
          if (!saved) throw StateError('Unable to save room history.');
          await _roomService.leaveRoom(widget.sessionId);
          await _participantClient?.disconnect();
        }
      }
      if (mounted) {
        setState(() => _exitApproved = true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).failedToSaveSession}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      _closingRoom = false;
    }
  }

  Future<void> _endRoom(String sessionId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('room_confirm_end_dialog'),
        title: Text(l10n.confirmEndTitle),
        content: Text(l10n.confirmEndBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.endReadingSession),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final ended = await _roomService.endSession(sessionId);
      if (!ended) throw StateError('Session could not be ended.');
      _discoveryService.stopBeacon();
      _hostServer?.broadcastSessionEnded();
      await _hostServer?.stop();
      if (mounted) setState(() => _lanConnectedCount = 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).failedToEndSession}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981);
      case 'paused':
        return const Color(0xFFF59E0B);
      case 'ended':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _exitApproved,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _promptRoomExit();
      },
      child: StreamBuilder<Session?>(
      stream: _sessionStream,
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.localReadingRooms)),
            body: Center(child: Text(l10n.roomNotFound)),
          );
        }

        final displayStatus = session.status == 'ended' ? l10n.ended
            : session.status == 'saved' ? l10n.savedStatus
            : session.status.toUpperCase();

        return Scaffold(
          appBar: AppBar(
            title: Text(session.title),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(session.status).withAlpha(30),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getStatusColor(session.status)),
                ),
                child: Text(
                  displayStatus,
                  style: TextStyle(
                    color: _getStatusColor(session.status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSessionCodeCard(session),
                const SizedBox(height: 16),
                _buildSessionControls(session),
                const SizedBox(height: 16),
                _buildBookCard(session),
                const SizedBox(height: 16),
                _buildParticipantsSection(session),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildSessionCodeCard(Session session) {
    final l10n = AppLocalizations.of(context);
    final isHost = _currentProfile != null && session.hostDeviceId == _currentProfile!.id;
    final hostEndpoint = _hostServer?.isRunning == true &&
            session.status != 'saved' && session.status != 'ended' &&
            _hostDisplayIp.isNotEmpty && !LanIpHelper.isLoopback(_hostDisplayIp)
        ? '$_hostDisplayIp:$_hostPort'
        : l10n.disconnected;

    return Card(
      elevation: 0,
      color: const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.roomCodeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.id,
                      key: const Key('room_code_display'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('copy_room_code_button'),
                      icon: AppIcon.copy(color: Color(0xFF2563EB)),
                      tooltip: l10n.copyCode,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: session.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.copiedToClipboard(session.id))),
                        );
                      },
                    ),
                    IconButton(
                      key: const Key('share_room_code_button'),
                      icon: const Icon(Icons.share, color: Color(0xFF2563EB)),
                      tooltip: l10n.tr('shareRoomCode'),
                      onPressed: () async {
                        try {
                          await AppSharingService.shareRoomCode(session.id,
                              arabic: l10n.isArabic);
                        } catch (error) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${l10n.tr('shareFailed')}: $error')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFDBEAFE), height: 1),
            const SizedBox(height: 10),
            if (isHost)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        AppIcon.wifi(size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.lanHost}: $hostEndpoint',
                            key: const Key('lan_host_endpoint_display'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_lanConnectedCount ${l10n.connected}',
                      key: const Key('lan_peer_count_display'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AppIcon.dot(size: 10, color: _participantState == LanConnectionState.connected
                            ? const Color(0xFF10B981)
                            : _participantState == LanConnectionState.connecting ||
                                    _participantState == LanConnectionState.reconnecting
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.lan}: ${_participantState == LanConnectionState.connected ? l10n.connected : _participantState == LanConnectionState.connecting ? l10n.connecting : _participantState == LanConnectionState.reconnecting ? l10n.reconnecting : l10n.disconnected}',
                        key: const Key('lan_connection_status_display'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  if (_participantState == LanConnectionState.disconnected &&
                      _participantClient != null && session.status != 'ended' &&
                      session.status != 'saved' &&
                      _sessionStatusForParticipant != 'ended' &&
                      _sessionStatusForParticipant != 'saved')
                    TextButton.icon(
                      key: const Key('reconnect_lan_button'),
                      onPressed: () {
                        _participantClient?.reconnect();
                      },
                      icon: AppIcon.refresh(size: 16),
                      label: Text(l10n.reconnect, style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControls(Session session) {
    final l10n = AppLocalizations.of(context);
    if (_currentProfile == null) return const SizedBox.shrink();
    final isHost = session.hostDeviceId == _currentProfile!.id;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isHost ? l10n.hostControls : l10n.roomStatus,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(
                    isHost ? l10n.youAreHost : l10n.youAreParticipant,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isHost) ...[
              if (session.status == 'created')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('start_session_button'),
                    onPressed: () async {
                      if (await _roomService.startSession(session.id)) {
                        _hostServer?.broadcastSessionStarted();
                      }
                    },
                    icon: AppIcon.play(),
                    label: Text(l10n.startReadingSession),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  ),
                ),
              if (session.status == 'active')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('pause_session_button'),
                        onPressed: () async {
                          if (await _roomService.pauseSession(session.id)) {
                            _hostServer?.broadcastSessionPaused();
                          }
                        },
                        icon: AppIcon.pause(),
                        label: Text(l10n.pause),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('end_session_button'),
                        onPressed: () => _endRoom(session.id),
                        icon: AppIcon.stop(),
                        label: Text(l10n.endRoom),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              if (session.status == 'paused')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('resume_session_button'),
                        onPressed: () async {
                          if (await _roomService.resumeSession(session.id)) {
                            _hostServer?.broadcastSessionResumed();
                          }
                        },
                        icon: AppIcon.play(),
                        label: Text(l10n.resume),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('end_session_button_paused'),
                        onPressed: () => _endRoom(session.id),
                        icon: AppIcon.stop(),
                        label: Text(l10n.endRoom),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              if (session.status == 'saved')
                Center(child: Text('${l10n.savedStatus} • ${l10n.mySessions}')),
              if (session.status == 'ended')
                Center(
                  child: Text(
                    l10n.sessionEnded,
                    style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ),
            ] else ...[
              Text(
                session.status == 'active'
                    ? l10n.hostRunning
                    : session.status == 'paused'
                        ? l10n.hostPaused
                        : session.status == 'saved' ? l10n.savedStatus : l10n.sessionEnded,
                style: const TextStyle(color: Color(0xFF475569)),
              ),
              if (_sessionStatusForParticipant == 'ended' || session.status == 'ended')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    l10n.endedRoomHistoryOnly,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Session session) {
    final l10n = AppLocalizations.of(context);
    if (_currentProfile == null) return const SizedBox.shrink();
    final isHost = session.hostDeviceId == _currentProfile!.id;
    final canRead = session.status != 'ended' && session.status != 'saved' &&
        (isHost ? _hostServer?.isRunning == true : _participantClient?.isJoined == true);

    return FutureBuilder<Book?>(
      future: _bookRepo.getBookById(session.bookId),
      builder: (context, snapshot) {
        final book = snapshot.data;
        if (book == null) return const SizedBox.shrink();

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.roomBook,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppIcon.book(color: Color(0xFF2563EB), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${book.pageCount} pages • By ${book.author}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('open_room_book_button'),
                    onPressed: !canRead
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfReaderScreen(
                                  book: book,
                                  sessionId: session.id,
                                  isHost: isHost,
                                  hostServer: _hostServer,
                                  participantClient: _participantClient,
                                  contentSync: _contentSync,
                                  onLanSessionClosed: _discoveryService.stopBeacon,
                                ),
                              ),
                            );
                          },
                    icon: AppIcon.book(),
                    label: Text(isHost ? l10n.readAsHost : l10n.readAsParticipant),
                  ),
                ),
                if (session.status == 'ended')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      l10n.endedRoomHistoryOnly,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsSection(Session session) {
    final l10n = AppLocalizations.of(context);
    final isEnded = session.status == 'ended';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.participants,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<SessionMember>>(
              stream: _membersStream,
              builder: (context, snapshot) {
                final allMembers = snapshot.data ?? [];
                // If session ended, show participants as not active – filter active only if not ended
                final members = allMembers;
                if (members.isEmpty) {
                  return Text(l10n.noParticipantsYet);
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isHostMember = member.role == 'host';
                    // After ended, no one should be shown as active
                    final displayStatus = isEnded
                        ? (isHostMember ? l10n.ended : l10n.left)
                        : (member.status == 'active'
                            ? l10n.active
                            : member.status == 'left'
                                ? l10n.left
                                : member.status);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isHostMember ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                        child: isHostMember
                            ? AppIcon.star(color: const Color(0xFF2563EB))
                            : AppIcon.person(color: const Color(0xFF64748B)),
                      ),
                      title: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.status}: $displayStatus',
                            style: TextStyle(
                              fontSize: 12,
                              color: (!isEnded && member.status == 'active')
                                  ? const Color(0xFF10B981) : Colors.grey,
                            ),
                          ),
                          if (_readingTimeRepo != null)
                            StreamBuilder<List<ParticipantReadingTime>>(
                              stream: _readingTimeRepo!.watchSessionTimes(session.id),
                              builder: (context, timeSnap) {
                                final found = timeSnap.data?.where(
                                    (t) => t.deviceId == member.deviceId).toList() ?? [];
                                if (found.isEmpty) return const SizedBox.shrink();
                                final seconds = found.first.totalSeconds;
                                final minutes = seconds ~/ 60;
                                final remainder = seconds % 60;
                                return Text('${l10n.tr('readTime')}: '
                                    '$minutes:${remainder.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11));
                              },
                            ),
                          if (_progressRepo != null)
                            StreamBuilder<List<ReadingProgress>>(
                              stream: _progressRepo!.watchSessionProgress(session.id),
                              builder: (context, progressSnap) {
                                final found = progressSnap.data?.where(
                                    (p) => p.deviceId == member.deviceId).toList() ?? [];
                                if (found.isEmpty) return const SizedBox.shrink();
                                return Text(
                                  '${l10n.tr('participantProgress')}: '
                                  '${l10n.pageOf(found.first.currentPage, found.first.totalPages)}',
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(
                          isHostMember ? l10n.host : l10n.member,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isHostMember ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                          ),
                        ),
                        backgroundColor: isHostMember ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
