import 'package:flutter/material.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';
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
    final books = await _bookRepo.getAllBooks();
    if (books.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please import a PDF book in the Library before creating a room.')),
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
              title: const Text('Create Reading Room'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Room Title',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: title),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Book',
                        border: OutlineInputBorder(),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create Room'),
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
            SnackBar(content: Text('Failed to create room: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Dialog to join an existing reading room with a session code.
  Future<void> _showJoinRoomDialog() async {
    final codeController = TextEditingController();
    final ipController = TextEditingController(text: '127.0.0.1');

    final joined = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Reading Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Room Code (e.g. RM-4821)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Host LAN IP (e.g. 192.168.1.50)',
                hintText: '127.0.0.1 for local device',
                border: OutlineInputBorder(),
              ),
            ),
            if (_discoveryService.discoveredRooms.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Discovered Rooms on LAN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              ..._discoveryService.discoveredRooms.map((r) => ActionChip(
                label: Text('${r.sessionId} - ${r.title} (${r.hostIp})'),
                onPressed: () {
                  codeController.text = r.sessionId;
                  ipController.text = r.hostIp;
                },
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (joined == true && codeController.text.trim().isNotEmpty) {
      try {
        final session = await _roomService.joinRoom(
          sessionCode: codeController.text.trim(),
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoomDetailScreen(
                sessionId: session.id,
                hostAddress: ipController.text.trim().isNotEmpty
                    ? ipController.text.trim()
                    : '127.0.0.1',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Join failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Reading Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login_rounded),
            tooltip: 'Join with Code',
            onPressed: _showJoinRoomDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add_home_rounded),
            tooltip: 'Create Room',
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
          // Filter out internal solo reading sessions
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 72, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'No Active Reading Rooms',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a reading room for a book or join one using a room code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showCreateRoomDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Room'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showJoinRoomDialog,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Join Room'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(Session room) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      room.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: room.status == 'active'
                        ? const Color(0xFF10B981)
                        : room.status == 'paused'
                            ? const Color(0xFFF59E0B)
                            : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    room.status.toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
