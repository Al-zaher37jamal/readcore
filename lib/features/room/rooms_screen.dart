import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';
import 'package:readmesh/features/lan/lan_ip_helper.dart';
import 'package:readmesh/features/room/local_room_service.dart';
import 'package:readmesh/features/room/room_detail_screen.dart';

/// Screen listing available local reading rooms and providing creation / joining actions.
class RoomsScreen extends StatefulWidget {
  final LocalRoomService? roomService;
  final SessionRepository? sessionRepository;
  final BookRepository? bookRepository;
  final LanDiscoveryService? discoveryService;

  const RoomsScreen({
    super.key,
    this.roomService,
    this.sessionRepository,
    this.bookRepository,
    this.discoveryService,
  });

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final LocalRoomService _roomService;
  late final SessionRepository _sessionRepo;
  late final BookRepository _bookRepo;
  late final LanDiscoveryService _discoveryService;
  late final Stream<List<Session>> _sessionsStream;

  @override
  void initState() {
    super.initState();
    _roomService = widget.roomService ?? getIt<LocalRoomService>();
    _sessionRepo = widget.sessionRepository ?? getIt<SessionRepository>();
    _bookRepo = widget.bookRepository ?? getIt<BookRepository>();
    _discoveryService = widget.discoveryService ??
        (getIt.isRegistered<LanDiscoveryService>()
            ? getIt<LanDiscoveryService>()
            : LanDiscoveryService());
    _sessionsStream = _sessionRepo.watchAllSessions();
    _discoveryService.startListening();
  }

  @override
  void dispose() {
    _discoveryService.stopListening();
    super.dispose();
  }

  /// Dialog to create a new reading room.
  Future<void> _showCreateRoomDialog() async {
    final l10n = AppLocalizations.of(context);
    final books = await _bookRepo.getAllBooks();
    if (books.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseImportBook)),
        );
      }
      return;
    }

    String title = 'Collaborative Reading Session';
    String selectedBookId = books.first.id;

    if (!mounted) return;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.createReadingRoom),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: l10n.roomTitle,
                        border: const OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: title),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: l10n.selectBook,
                        border: const OutlineInputBorder(),
                      ),
                      value: selectedBookId,
                      items: books.map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            b.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedBookId = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.createRoom),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      try {
        final session = await _roomService.createRoom(
          title: title,
          bookId: selectedBookId,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(sessionId: session.id),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.failedToCreateRoom}: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Dialog to join an existing reading room with a session code.
  /// FIXED: Accepts 10.87.235.106 (10/8 private) and 10.87.235.106:40404 host:port, validates correctly.
  Future<void> _showJoinRoomDialog() async {
    final l10n = AppLocalizations.of(context);
    final codeController = TextEditingController();
    final ipController = TextEditingController();

    final joined = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.joinReadingRoom),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.roomCodeExample,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ipController,
                      decoration: InputDecoration(
                        labelText: l10n.hostLanIpExample,
                        hintText: 'e.g. 10.87.235.106 or 192.168.0.73:40404',
                        border: const OutlineInputBorder(),
                        helperText: 'e.g. 10.87.235.106, 192.168.0.73, or 10.87.235.106:40404',
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.hostLanIpHint}\n${l10n.isArabic ? 'مثال: 10.87.235.106 أو 10.87.235.106:40404' : 'Example: 10.87.235.106 or 10.87.235.106:40404'}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    StreamBuilder<List<DiscoveredRoom>>(
                      stream: _discoveryService.roomsStream,
                      builder: (context, snap) {
                        final discovered = _discoveryService.discoveredRooms;
                        if (discovered.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(l10n.discoveredRoomsOnLan,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: discovered.map((r) => ActionChip(
                                label: Text('${r.sessionId} - ${r.title} (${r.hostIp}:${r.port})'),
                                onPressed: () {
                                  codeController.text = r.sessionId;
                                  ipController.text = '${r.hostIp}:${r.port}';
                                  setState(() {});
                                },
                              )).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, {
                      'code': codeController.text.trim(),
                      'ip': ipController.text.trim(),
                    });
                  },
                  child: Text(l10n.join),
                ),
              ],
            );
          },
        );
      },
    );

    if (joined == null) return;
    final code = (joined['code'] ?? '').trim();
    final ipInput = (joined['ip'] ?? '').trim();

    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidCode), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (ipInput.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidIp), backgroundColor: Colors.red),
        );
      }
      return;
    }
    // Parse host input that may be bare IPv4 or IP:port - FIX for 10.87.235.106
    final parsed = LanIpHelper.parseHostPort(ipInput, defaultPort: 40404);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidIp), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final ip = parsed.ip;
    final port = parsed.port;

    if (!LanIpHelper.isValidIPv4Any(ip)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidIp), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      // For remote LAN join, pass remoteTitle if discovered
      String? remoteTitle;
      try {
        final discovered = _discoveryService.discoveredRooms;
        final match = discovered.where((r) => r.sessionId.toUpperCase() == code.toUpperCase()).toList();
        if (match.isNotEmpty) remoteTitle = match.first.title;
      } catch (_) {}

      final session = await _roomService.joinRoom(
        sessionCode: code,
        remoteTitle: remoteTitle,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoomDetailScreen(
              sessionId: session.id,
              hostAddress: ip,
              port: port,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String friendlyMessage;
      if (e is NotFoundException) {
        friendlyMessage = l10n.roomNotFound;
      } else if (e is DatabaseOperationException && e.message.contains('ended')) {
        friendlyMessage = l10n.cannotJoinEnded;
      } else {
        if (e.toString().contains('ended')) {
          friendlyMessage = l10n.cannotJoinEnded;
        } else {
          friendlyMessage = l10n.roomNotFound;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.localReadingRooms),
        actions: [
          IconButton(
            icon: AppIcon.login(),
            tooltip: l10n.joinWithCode,
            onPressed: _showJoinRoomDialog,
          ),
          IconButton(
            icon: AppIcon.add(),
            tooltip: l10n.createRoom,
            onPressed: _showCreateRoomDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<Session>>(
        stream: _sessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allSessions = snapshot.data ?? [];
          final rooms = allSessions.where((s) => !s.id.startsWith('solo_')).toList();

          if (rooms.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final room = rooms[index];
              return _buildRoomCard(room);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon.group(size: 72, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              l10n.noActiveReadingRooms,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createRoomHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showCreateRoomDialog,
                  icon: AppIcon.add(),
                  label: Text(l10n.createRoom),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showJoinRoomDialog,
                  icon: AppIcon.login(),
                  label: Text(l10n.joinRoom),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(Session room) {
    final l10n = AppLocalizations.of(context);
    final isEnded = room.status == 'ended';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isEnded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.endedRoomHistoryOnly)),
            );
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(sessionId: room.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      room.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEnded ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isEnded ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      room.id,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isEnded ? const Color(0xFF64748B) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AppIcon.dot(size: 10, color: room.status == 'active'
                        ? const Color(0xFF10B981)
                        : room.status == 'paused'
                            ? const Color(0xFFF59E0B)
                            : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isEnded ? '${room.status.toUpperCase()} - ${l10n.historyOnly}' : room.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isEnded ? const Color(0xFF64748B) : null,
                    ),
                  ),
                  if (isEnded) ...[
                    const SizedBox(width: 8),
                    AppIcon.history(size: 14, color: const Color(0xFF94A3B8)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
