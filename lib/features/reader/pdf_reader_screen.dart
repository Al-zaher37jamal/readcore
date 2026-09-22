import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
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
/// FIXED: Real PDF page synchronization Host 1→2→5→10 Participant visibly follows, pending jumps, totalPages sync, pause/resume/reconnect.
class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final String? sessionId;
  final bool isHost;
  final LanHostServer? hostServer;
  final LanParticipantClient? participantClient;

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
      _participantPageSub = widget.participantClient!.pageStream.listen((syncedPage) {
        if (!mounted || _sessionStatus == 'ended') return;
        final client = widget.participantClient!;
        final newTotal = client.totalPages;
        final shouldUpdatePage = syncedPage != _currentPage;
        final shouldUpdateTotal = newTotal != _totalPages && newTotal > 0;

        if (shouldUpdatePage || shouldUpdateTotal) {
          setState(() {
            if (shouldUpdatePage) {
              _currentPage = syncedPage.clamp(1, newTotal > 0 ? newTotal : _totalPages);
            }
            if (shouldUpdateTotal) {
              _totalPages = newTotal;
            }
          });
          _saveProgress();
        }
      });

      _participantStatusSub = widget.participantClient!.statusStream.listen((status) {
        if (!mounted) return;
        final client = widget.participantClient!;
        setState(() {
          _sessionStatus = status;
          if (client.totalPages > 0 && client.totalPages != _totalPages) {
            _totalPages = client.totalPages;
          }
          if (client.currentPage != _currentPage && _sessionStatus != 'ended') {
            _currentPage = client.currentPage.clamp(1, _totalPages);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _participantPageSub?.cancel();
    _participantStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeReader() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.book.filePath);
      if (!file.existsSync()) {
        setState(() {
          _errorMessage = 'PDF file not found on device: ${widget.book.filePath}';
          _isLoading = false;
        });
        return;
      }
      final profile = await _deviceService.getOrCreateCurrentProfile();
      _deviceId = profile.id;

      final existingSession = await _sessionRepo.getSessionById(_activeSessionId);
      if (existingSession == null) {
        await _sessionRepo.createSession(
          id: _activeSessionId,
          title: widget.sessionId != null ? 'Room Session' : 'Personal Reading',
          hostDeviceId: _deviceId,
          bookId: widget.book.id,
          status: 'active',
        );
      } else {
        if (existingSession.status == 'ended') {
          setState(() {
            _sessionStatus = 'ended';
          });
        }
      }

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

      // For participant, prioritize authoritative LAN state over local saved progress
      if (!widget.isHost && widget.participantClient != null) {
        final lanPage = widget.participantClient!.currentPage;
        final lanTotal = widget.participantClient!.totalPages;
        if (lanPage > 0 && lanPage != _currentPage) {
          _currentPage = lanPage.clamp(1, lanTotal > 0 ? lanTotal : _totalPages);
        }
        if (lanTotal > 0) {
          _totalPages = lanTotal;
        }
      }

      await _saveProgress();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (!widget.isHost && widget.participantClient != null) {
          final lanPage = widget.participantClient!.currentPage;
          if (lanPage != _currentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentPage = lanPage.clamp(1, _totalPages);
                });
              }
            });
          }
        }
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
    } catch (_) {}
  }

  void previousPage() {
    if (_sessionStatus == 'ended') return;
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

  void nextPage() {
    if (_sessionStatus == 'ended') return;
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

  void goToPage(int page) {
    if (_sessionStatus == 'ended') return;
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

  void _showJumpToPageDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _currentPage.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.jumpToPage),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.pageNumberRange(_totalPages),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null) {
                goToPage(page);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.go),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                '${l10n.roomCode}: ${widget.sessionId}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: AppIcon.bookmark(),
            tooltip: l10n.jumpToPage,
            onPressed: _isLoading || _errorMessage != null || _sessionStatus == 'ended' ? null : _showJumpToPageDialog,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.openingDocument,
              style: const TextStyle(color: Color(0xFF64748B)),
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
              AppIcon.error(size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _initializeReader,
                icon: AppIcon.refresh(),
                label: Text(l10n.go),
              ),
            ],
          ),
        ),
      );
    }

    final isParticipantMode = !widget.isHost && widget.sessionId != null;

    return Column(
      children: [
        if (_sessionStatus == 'paused')
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF3C7),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon.pause(size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Text(
                  l10n.readingSessionPaused,
                  style: const TextStyle(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon.stop(size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  l10n.readingSessionEnded,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        LinearProgressIndicator(
          value: _totalPages > 0 ? (_currentPage / _totalPages) : 0,
          backgroundColor: const Color(0xFFE2E8F0),
          color: isParticipantMode ? const Color(0xFF10B981) : const Color(0xFF2563EB),
          minHeight: 4,
        ),
        Expanded(
          child: _sessionStatus == 'ended'
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon.cancel(size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          l10n.sessionEnded,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.endedRoomHistoryOnly,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : PdfPageView(
                  filePath: widget.book.filePath,
                  pageNumber: _currentPage,
                  totalPages: _totalPages,
                  bookTitle: widget.book.title,
                  author: widget.book.author,
                  onPageChanged: (page) {
                    if (widget.isHost && page != _currentPage && _sessionStatus != 'ended') {
                      setState(() {
                        _currentPage = page;
                      });
                      _saveProgress();
                      widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
                    } else if (!widget.isHost) {
                      if (page != _currentPage) {
                        setState(() {
                          _currentPage = page;
                        });
                        _saveProgress();
                      }
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);
    final isParticipantMode = !widget.isHost && widget.sessionId != null;
    final isEnded = _sessionStatus == 'ended';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              key: const Key('prev_page_button'),
              icon: AppIcon.back(size: 32),
              onPressed: !isParticipantMode && !isEnded && _currentPage > 1 ? previousPage : null,
              tooltip: isParticipantMode ? l10n.waitingForParticipants : 'Previous Page',
            ),
            InkWell(
              onTap: isParticipantMode || isEnded ? null : _showJumpToPageDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isParticipantMode) ...[
                      AppIcon.refresh(size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isParticipantMode
                          ? l10n.syncedPage(_currentPage, _totalPages)
                          : l10n.pageOf(_currentPage, _totalPages),
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
            IconButton(
              key: const Key('next_page_button'),
              icon: AppIcon.forward(size: 32),
              onPressed: !isParticipantMode && !isEnded && _currentPage < _totalPages ? nextPage : null,
              tooltip: isParticipantMode ? l10n.waitingForParticipants : 'Next Page',
            ),
          ],
        ),
      ),
    );
  }
}
