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
/// Phase 6: Session History and Resumable Local Reading
/// - Save and Leave vs End Reading Session dialog
/// - Auto-save reading position on page change
/// - Resume restores PDF + saved page + metadata + fresh LAN server
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

  // Phase 6: timer and stats
  bool _timerEnabled = false;
  bool _statsEnabled = false;
  Timer? _readingTimer;
  int _elapsedSeconds = 0;
  DateTime? _sessionStartTime;

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
    _readingTimer?.cancel();
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
        } else {
          setState(() {
            _sessionStatus = existingSession.status;
          });
        }
      }

      // Phase 6: load timer/stats flags
      try {
        final flags = await _sessionRepo.getSessionFlags(_activeSessionId);
        if (flags != null) {
          _timerEnabled = flags['timerEnabled'] as bool? ?? false;
          _statsEnabled = flags['statsEnabled'] as bool? ?? false;
        }
      } catch (_) {}

      ReadingProgress? savedProgress;
      if (widget.sessionId != null) {
        savedProgress = await _progressRepo.getProgress(_activeSessionId, _deviceId);
      }
      savedProgress ??= await _progressRepo.getLatestBookProgress(widget.book.id, _deviceId);

      if (savedProgress != null &&
          savedProgress.currentPage >= 1 &&
          savedProgress.currentPage <= _totalPages) {
        _currentPage = savedProgress.currentPage;
        if (savedProgress.totalPages > 0) {
          _totalPages = savedProgress.totalPages;
        }
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
      _startTimerIfEnabled();

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

  void _startTimerIfEnabled() {
    if (!_timerEnabled) return;
    _sessionStartTime = DateTime.now();
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
      // Phase 6: also update session last page for My Sessions card
      try {
        await _sessionRepo.updateSessionLastPage(_activeSessionId, _currentPage, _totalPages);
      } catch (_) {}
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

  // Phase 6: Leave dialog "ماذا تريد أن تفعل؟"
  Future<bool> _showLeaveDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const Key('leave_session_dialog'),
        title: Text(l10n.whatWouldYouDo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_timerEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    AppIcon.history(size: 18, color: const Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text('${l10n.timerEnabledLabel}: ${_formatElapsed(_elapsedSeconds)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ElevatedButton.icon(
              key: const Key('save_and_leave_button'),
              onPressed: () => Navigator.pop(ctx, 'save'),
              icon: AppIcon.bookmark(size: 20),
              label: Text(l10n.saveAndLeave),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const Key('end_reading_session_button'),
              onPressed: () => Navigator.pop(ctx, 'end'),
              icon: AppIcon.stop(size: 20),
              label: Text(l10n.endReadingSession),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('cancel_leave_button'),
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );

    if (result == 'save') {
      await _handleSaveAndLeave();
      return true; // allow pop
    } else if (result == 'end') {
      final confirmed = await _showEndConfirmation();
      if (confirmed) {
        await _handleEndReadingSession();
        return true;
      }
      return false;
    }
    return false; // cancel
  }

  Future<bool> _showEndConfirmation() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('confirm_end_dialog'),
        title: Text(l10n.confirmEndTitle),
        content: Text(l10n.confirmEndBody),
        actions: [
          TextButton(
            key: const Key('cancel_end_button'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_end_button'),
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: Text(l10n.endReadingSession),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _handleSaveAndLeave() async {
    try {
      await _saveProgress();
      await _sessionRepo.saveAndLeaveSession(_activeSessionId, lastPage: _currentPage, totalPages: _totalPages);
      // For group host, disconnect participants cleanly but keep history
      if (widget.isHost && widget.hostServer != null) {
        try {
          await widget.hostServer!.stop();
        } catch (_) {}
      }
      if (!widget.isHost && widget.participantClient != null) {
        try {
          await widget.participantClient!.disconnect();
        } catch (_) {}
      }
      _readingTimer?.cancel();
    } catch (_) {}
  }

  Future<void> _handleEndReadingSession() async {
    try {
      await _saveProgress();
      await _sessionRepo.endReadingSession(_activeSessionId);
      // Disconnect participants and stop sync
      if (widget.isHost && widget.hostServer != null) {
        try {
          widget.hostServer!.broadcastSessionEnded();
          await widget.hostServer!.stop();
        } catch (_) {}
      }
      if (!widget.isHost && widget.participantClient != null) {
        try {
          await widget.participantClient!.disconnect();
        } catch (_) {}
      }
      _readingTimer?.cancel();
      if (_statsEnabled && mounted) {
        await _showEndStats();
      }
    } catch (_) {}
  }

  Future<void> _showEndStats() async {
    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.statsEnabledLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.pageOf(_currentPage, _totalPages)}'),
            const SizedBox(height: 8),
            if (_timerEnabled) Text('${l10n.timerEnabledLabel}: ${_formatElapsed(_elapsedSeconds)}'),
            const SizedBox(height: 8),
            Text('${l10n.lastReadingPrefix}: ${DateTime.now().toString().substring(0, 19)}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_sessionStatus == 'ended') {
          if (mounted) Navigator.pop(context);
          return;
        }
        final shouldPop = await _showLeaveDialog();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
            if (_timerEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Center(
                  child: Text(
                    _formatElapsed(_elapsedSeconds),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            IconButton(
              icon: AppIcon.bookmark(),
              tooltip: l10n.jumpToPage,
              onPressed: _isLoading || _errorMessage != null || _sessionStatus == 'ended' ? null : _showJumpToPageDialog,
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _isLoading || _errorMessage != null ? null : _buildBottomBar(),
      ),
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
                        if (_statsEnabled) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${l10n.pageOf(_currentPage, _totalPages)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          if (_timerEnabled)
                            Text(
                              '${l10n.timerEnabledLabel}: ${_formatElapsed(_elapsedSeconds)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                        ],
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
