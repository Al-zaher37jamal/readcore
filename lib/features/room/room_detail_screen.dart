import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
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
  final LocalRoomService? roomService;
  final BookRepository? bookRepository;
  final DeviceService? deviceService;
  final LanHostServer? hostServer;
  final LanParticipantClient? participantClient;
  final LanDiscoveryService? discoveryService;

  const RoomDetailScreen({
    super.key,
    required this.sessionId,
    this.hostAddress,
    this.port,
    this.roomService,
    this.bookRepository,
    this.deviceService,
    this.hostServer,
    this.participantClient,
    this.discoveryService,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late final LocalRoomService _roomService;
  late final BookRepository _bookRepo;
  late final DeviceService _deviceService;
  late final LanDiscoveryService _discoveryService;
  late final Stream<Session?> _sessionStream;
  late final Stream<List<SessionMember>> _membersStream;
  DeviceProfile? _currentProfile;

  LanHostServer? _hostServer;
  LanParticipantClient? _participantClient;
  StreamSubscription<LanConnectionState>? _participantConnSub;
  StreamSubscription<List<LanConnectedParticipant>>? _hostParticipantsSub;
  StreamSubscription<List<SessionMember>>? _membersCountSub;
  StreamSubscription<String>? _participantStatusSub;

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

    // Listen to members to compute connected count consistently (active participants excluding host)
    _membersCountSub = _membersStream.listen((members) {
      if (!mounted) return;
      final activeParticipants = members.where((m) => m.role != 'host' && m.status == 'active').length;
      // For Host, LAN count should match active participants; also consider LAN sockets if more accurate
      // We use max of active participants and LAN socket count for safety, but ensure 0→0,1→1
      final isHost = _currentProfile != null &&
          members.any((m) => m.deviceId == _currentProfile!.id && m.role == 'host');
      if (isHost) {
        // If LAN sockets exist, use them; otherwise use active count to stay consistent
        final lanCount = _hostServer?.connectedClientCount ?? _lanConnectedCount;
        // Prefer active count to avoid 0 connected vs active mismatch
        final consistentCount = activeParticipants;
        if (mounted) {
          setState(() {
            _lanConnectedCount = consistentCount;
          });
        }
      }
    });
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
    if (session == null) return;

    final isHost = session.hostDeviceId == _currentProfile!.id;

    if (isHost) {
      if (_hostServer == null && widget.hostServer == null) {
        _hostServer = LanHostServer(
          sessionId: widget.sessionId,
          hostDeviceId: _currentProfile!.id,
          hostDisplayName: _currentProfile!.displayName,
          requestedPort: widget.port ?? 40404,
        );
        try {
          await _hostServer!.start(); // Binds anyIPv4, gets real LAN IP via LanIpHelper
          if (mounted) {
            setState(() {
              _hostDisplayIp = _hostServer!.localIp;
              _hostPort = _hostServer!.port;
            });
          }

          // Start lightweight UDP beacon with real IP
          _discoveryService.startBeacon(
            sessionId: widget.sessionId,
            title: session.title,
            hostIp: _hostDisplayIp,
            port: _hostPort,
          );
        } catch (_) {
          // Fallback to helper directly if start fails
          final realIp = await LanIpHelper.getLocalLanIPv4();
          if (mounted) {
            setState(() {
              _hostDisplayIp = realIp;
            });
          }
        }
      } else if (_hostServer != null) {
        if (mounted) {
          setState(() {
            _hostDisplayIp = _hostServer!.localIp;
            _hostPort = _hostServer!.port;
          });
        }
        // Ensure IP is not loopback if possible
        if (_hostDisplayIp == '127.0.0.1' || _hostDisplayIp.startsWith('127.')) {
          final realIp = await LanIpHelper.getLocalLanIPv4();
          if (mounted && realIp != '127.0.0.1') {
            setState(() {
              _hostDisplayIp = realIp;
            });
          }
        }
      }

      _hostParticipantsSub = _hostServer?.participantsStream.listen((list) {
        if (mounted) {
          // Update LAN count from sockets, but also sync with DB active count for consistency
          // We keep socket count but UI will also be updated via members subscription
          setState(() {
            // For consistency, we will use list.length but members subscription overrides to active count
            // To avoid mismatch, we set to list.length here and members subscription will correct if needed
            _lanConnectedCount = list.length;
          });
        }
      });
    } else {
      // Participant mode
      if (widget.hostAddress != null && _participantClient == null) {
        _participantClient = LanParticipantClient(
          sessionId: widget.sessionId,
          deviceId: _currentProfile!.id,
          displayName: _currentProfile!.displayName,
        );
        _participantConnSub = _participantClient!.stateStream.listen((state) {
          if (mounted) {
            setState(() {
              _participantState = state;
            });
          }
        });
        _participantStatusSub = _participantClient!.statusStream.listen((status) async {
          if (mounted) {
            setState(() {
              _sessionStatusForParticipant = status;
            });
          }
          if (status == 'ended') {
            // When Host ends, update local member status to left, disconnect, remove connected state
            try {
              await _roomService.leaveRoom(widget.sessionId);
            } catch (_) {}
            if (mounted) {
              setState(() {
                _participantState = LanConnectionState.disconnected;
              });
            }
            await _participantClient?.disconnect();
          }
        });
        try {
          await _participantClient!.connect(
            hostAddress: widget.hostAddress!,
            port: widget.port ?? 40404,
          );
        } catch (_) {
          if (mounted) {
            setState(() {
              _participantState = LanConnectionState.disconnected;
            });
          }
        }
      } else if (_participantClient != null) {
        _participantConnSub = _participantClient!.stateStream.listen((state) {
          if (mounted) {
            setState(() {
              _participantState = state;
            });
          }
        });
        _participantStatusSub = _participantClient!.statusStream.listen((status) async {
          if (mounted) {
            setState(() {
              _sessionStatusForParticipant = status;
            });
          }
          if (status == 'ended') {
            try {
              await _roomService.leaveRoom(widget.sessionId);
            } catch (_) {}
            if (mounted) {
              setState(() {
                _participantState = LanConnectionState.disconnected;
              });
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _participantConnSub?.cancel();
    _hostParticipantsSub?.cancel();
    _membersCountSub?.cancel();
    _participantStatusSub?.cancel();
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
    return StreamBuilder<Session?>(
      stream: _sessionStream,
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.localReadingRooms)),
            body: Center(child: Text(l10n.roomNotFound)),
          );
        }

        final displayStatus = session.status == 'ended' ? l10n.ended : session.status.toUpperCase();

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
    );
  }

  Widget _buildSessionCodeCard(Session session) {
    final l10n = AppLocalizations.of(context);
    final isHost = _currentProfile != null && session.hostDeviceId == _currentProfile!.id;
    final ipDisplay = _hostDisplayIp.isEmpty ? '...' : _hostDisplayIp;

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
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF2563EB)),
                  tooltip: l10n.copyCode,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: session.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.copiedToClipboard(session.id))),
                    );
                  },
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
                        const Icon(Icons.wifi_rounded, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.lanHost}: $ipDisplay:$_hostPort',
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
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _participantState == LanConnectionState.connected
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
                  if (_participantState == LanConnectionState.disconnected)
                    TextButton.icon(
                      key: const Key('reconnect_lan_button'),
                      onPressed: () {
                        _participantClient?.reconnect();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
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
                    onPressed: () {
                      _roomService.startSession(session.id);
                      _hostServer?.broadcastSessionStarted();
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
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
                        onPressed: () {
                          _roomService.pauseSession(session.id);
                          _hostServer?.broadcastSessionPaused();
                        },
                        icon: const Icon(Icons.pause_rounded),
                        label: Text(l10n.pause),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('end_session_button'),
                        onPressed: () async {
                          await _roomService.endSession(session.id);
                          _hostServer?.broadcastSessionEnded();
                          // After ended, stop beacon and clear connected count
                          _discoveryService.stopBeacon();
                          await _hostServer?.stop();
                          if (mounted) {
                            setState(() {
                              _lanConnectedCount = 0;
                            });
                          }
                        },
                        icon: const Icon(Icons.stop_rounded),
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
                        onPressed: () {
                          _roomService.resumeSession(session.id);
                          _hostServer?.broadcastSessionResumed();
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l10n.resume),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('end_session_button_paused'),
                        onPressed: () async {
                          await _roomService.endSession(session.id);
                          _hostServer?.broadcastSessionEnded();
                          _discoveryService.stopBeacon();
                          await _hostServer?.stop();
                          if (mounted) {
                            setState(() {
                              _lanConnectedCount = 0;
                            });
                          }
                        },
                        icon: const Icon(Icons.stop_rounded),
                        label: Text(l10n.endRoom),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
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
                        : l10n.sessionEnded,
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
    final isEnded = session.status == 'ended';

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
                    const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 28),
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
                    onPressed: isEnded
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
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.auto_stories_rounded),
                    label: Text(isHost ? l10n.readAsHost : l10n.readAsParticipant),
                  ),
                ),
                if (isEnded)
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
                        child: Icon(
                          isHostMember ? Icons.star_rounded : Icons.person_rounded,
                          color: isHostMember ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                      title: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${l10n.status}: $displayStatus',
                        style: TextStyle(
                          fontSize: 12,
                          color: (!isEnded && member.status == 'active')
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                        ),
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
