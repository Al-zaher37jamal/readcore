import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_page_view.dart';

/// Screen that opens an imported PDF, renders pages, tracks reading position,
/// navigates across pages, and automatically saves/restores progress from SQLite.
/// In a multi-device LAN session, synchronizes page turns and session lifecycle between Host and Participants.
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final String? sessionId;
  final bool isHost;
  final LanHostServer? hostServer;
  final LanParticipantClient? participantClient;

  // Optional injections for unit/widget testing
  final ReadingProgressRepository? readingProgressRepository;
  final DeviceService? deviceService;
  final SessionRepository? sessionRepository;

  const PdfReaderScreen({
    super.key,
    required this.book,
    this.sessionId,
    this.isHost = true,
    this.hostServer,
    this.participantClient,
    this.readingProgressRepository,
    this.deviceService,
    this.sessionRepository,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final ReadingProgressRepository _progressRepo;
  late final DeviceService _deviceService;
  late final SessionRepository _sessionRepo;

  StreamSubscription<int>? _participantPageSub;
  StreamSubscription<String>? _participantStatusSub;

  bool _isLoading = true;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;
  late String _activeSessionId;
  String _deviceId = '';
  String _sessionStatus = 'active';

  @override
  void initState() {
    super.initState();
    _progressRepo = widget.readingProgressRepository ?? getIt<ReadingProgressRepository>();
    _deviceService = widget.deviceService ?? getIt<DeviceService>();
    _sessionRepo = widget.sessionRepository ?? getIt<SessionRepository>();

    _totalPages = widget.book.pageCount > 0 ? widget.book.pageCount : 1;
    _activeSessionId = widget.sessionId ?? 'solo_${widget.book.id}';

    _initializeReader();
    _setupLanSyncSubscriptions();
  }

  void _setupLanSyncSubscriptions() {
    if (!widget.isHost && widget.participantClient != null) {
      // 1. Follow Host's authoritative page changes
      _participantPageSub = widget.participantClient!.pageStream.listen((syncedPage) {
        if (mounted && syncedPage != _currentPage) {
          setState(() {
            _currentPage = syncedPage;
          });
          _saveProgress();
        }
      });

      // 2. Reflect Host's session status (active, paused, ended)
      _participantStatusSub = widget.participantClient!.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _sessionStatus = status;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _participantPageSub?.cancel();
    _participantStatusSub?.cancel();
    super.dispose();
  }

  /// Initializes the reader, verifies the physical file, ensures session exists,
  /// and restores the last saved reading position from SQLite.
  Future<void> _initializeReader() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify physical file exists
      final file = File(widget.book.filePath);
      if (!file.existsSync()) {
        setState(() {
          _errorMessage = 'PDF file not found on device: ${widget.book.filePath}';
          _isLoading = false;
        });
        return;
      }
      // 2. Identify local device
      final profile = await _deviceService.getOrCreateCurrentProfile();
      _deviceId = profile.id;

      // 3. Ensure a session record exists in SQLite for foreign key integrity
      final existingSession = await _sessionRepo.getSessionById(_activeSessionId);
      if (existingSession == null) {
        await _sessionRepo.createSession(
          id: _activeSessionId,
          title: widget.sessionId != null ? 'Room Session' : 'Personal Reading',
          hostDeviceId: _deviceId,
          bookId: widget.book.id,
          status: 'active',
        );
      }

      // 4. Restore the last reading position from SQLite
      ReadingProgress? savedProgress;
      if (widget.sessionId != null) {
        savedProgress = await _progressRepo.getProgress(_activeSessionId, _deviceId);
      }
      savedProgress ??= await _progressRepo.getLatestBookProgress(widget.book.id, _deviceId);

      if (savedProgress != null &&
          savedProgress.currentPage >= 1 &&
          savedProgress.currentPage <= _totalPages) {
        _currentPage = savedProgress.currentPage;
      } else {
        _currentPage = 1;
      }

      // Initial save to establish reading position
      await _saveProgress();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading book: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Saves the current page progress asynchronously to SQLite.
  Future<void> _saveProgress() async {
    if (_deviceId.isEmpty) return;
    try {
      final progressId = 'prog_${_activeSessionId}_${widget.book.id}_$_deviceId';
      await _progressRepo.updateProgress(
        id: progressId,
        sessionId: _activeSessionId,
        bookId: widget.book.id,
        deviceId: _deviceId,
        currentPage: _currentPage,
        totalPages: _totalPages,
      );
    } catch (_) {
      // Background save error handling
    }
  }

  /// Navigates to the previous page (Host or Solo).
  void previousPage() {
    if (!widget.isHost && widget.sessionId != null) return;
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _saveProgress();
      if (widget.isHost) {
        widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
      }
    }
  }

  /// Navigates to the next page (Host or Solo).
  void nextPage() {
    if (!widget.isHost && widget.sessionId != null) return;
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
      });
      _saveProgress();
      if (widget.isHost) {
        widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
      }
    }
  }

  /// Jumps to a specific page number.
  void goToPage(int page) {
    if (!widget.isHost && widget.sessionId != null) return;
    final targetPage = page.clamp(1, _totalPages);
    if (targetPage != _currentPage) {
      setState(() {
        _currentPage = targetPage;
      });
      _saveProgress();
      if (widget.isHost) {
        widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
      }
    }
  }

  /// Opens jump to page dialog.
  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: _currentPage.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - $_totalPages)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null) {
                goToPage(page);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.sessionId != null)
              Text(
                'Room: ${widget.sessionId}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Jump to Page',
            onPressed: _isLoading || _errorMessage != null ? null : _showJumpToPageDialog,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Opening document...',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _initializeReader,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final isParticipantMode = !widget.isHost && widget.sessionId != null;

    return Column(
      children: [
        // Status Alert Banners
        if (_sessionStatus == 'paused')
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pause_circle_outline, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text(
                  'Reading Session Paused by Host',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (_sessionStatus == 'ended')
          Container(
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stop_circle_outlined, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  'Reading Session Ended by Host',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

        // Reading Progress Indicator Bar
        LinearProgressIndicator(
          value: _totalPages > 0 ? (_currentPage / _totalPages) : 0,
          backgroundColor: const Color(0xFFE2E8F0),
          color: isParticipantMode ? const Color(0xFF10B981) : const Color(0xFF2563EB),
          minHeight: 4,
        ),

        // PDF Page Rendering View - REAL PDF rendering from local file
        Expanded(
          child: PdfPageView(
            filePath: widget.book.filePath,
            pageNumber: _currentPage,
            totalPages: _totalPages,
            bookTitle: widget.book.title,
            author: widget.book.author,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isParticipantMode = !widget.isHost && widget.sessionId != null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous Page Button
            IconButton(
              key: const Key('prev_page_button'),
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
              onPressed: !isParticipantMode && _currentPage > 1 ? previousPage : null,
              tooltip: isParticipantMode ? 'Page controlled by Host' : 'Previous Page',
            ),

            // Page Number Display & Jump
            InkWell(
              onTap: isParticipantMode ? null : _showJumpToPageDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isParticipantMode) ...[
                      const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isParticipantMode
                          ? 'Synced: Page $_currentPage of $_totalPages'
                          : 'Page $_currentPage of $_totalPages',
                      key: const Key('page_number_display'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isParticipantMode ? const Color(0xFF047857) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Next Page Button
            IconButton(
              key: const Key('next_page_button'),
              icon: const Icon(Icons.chevron_right_rounded, size: 32),
              onPressed: !isParticipantMode && _currentPage < _totalPages ? nextPage : null,
              tooltip: isParticipantMode ? 'Page controlled by Host' : 'Next Page',
            ),
          ],
        ),
      ),
    );
  }
}
