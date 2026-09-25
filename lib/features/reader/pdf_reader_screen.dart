import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/audio_message_repository.dart';
import 'package:readmesh/features/audio_messages/data/local_audio_service.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'package:readmesh/features/session_content/session_content_panel.dart';
import 'package:readmesh/features/session_content/voice_audio_service.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_panel.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_controller.dart';
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
  final VoidCallback? onLanSessionClosed;
  final SessionContentSync? contentSync;
  final SessionContentRepository? contentRepository;
  final SessionVoiceStore? voiceStore;
  final VoiceAudioService? audioService;
  /// Earlier Notes/Voice/Highlight UI is retained for legacy callers only;
  /// the default reader shows inline, offline text/audio messages instead.
  final bool showLegacySessionContent;
  /// Injectable presentation boundary for isolated reader widget tests.
  final TextMessagesController? textMessagesController;
  final AudioMessageRepository? audioMessageRepository;
  final LocalAudioService? messageAudioService;
  final ParticipantReadingTimeRepository? readingTimeRepository;

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
    this.onLanSessionClosed,
    this.contentSync,
    this.contentRepository,
    this.voiceStore,
    this.audioService,
    this.showLegacySessionContent = false,
    this.textMessagesController,
    this.audioMessageRepository,
    this.messageAudioService,
    this.readingTimeRepository,
    this.readingProgressRepository,
    this.deviceService,
    this.sessionRepository,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> with WidgetsBindingObserver {
  late final ReadingProgressRepository _progressRepo;
  late final DeviceService _deviceService;
  late final SessionRepository _sessionRepo;
  ParticipantReadingTimeRepository? _readingTimeRepo;
  SessionContentSync? _contentSync;
  bool _ownsContentSync = false;
  bool _highlightMode = false;
  bool _highlightShared = false;
  Timer? _activityTimer;
  DateTime? _lastActivityAt;
  Future<void> _lastActivityWrite = Future<void>.value();

  StreamSubscription<int>? _participantPageSub;
  StreamSubscription<String>? _participantStatusSub;

  bool _isLoading = true;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;
  late String _activeSessionId;
  String _deviceId = '';
  String _displayName = '';
  String _sessionStatus = 'active';
  bool _exitApproved = false;
  bool _leaveInProgress = false;
  Future<void> _lastProgressWrite = Future<void>.value();

  bool get _canTurnPage => _sessionStatus == 'active' || _sessionStatus == 'created';
  bool get _isGroup => widget.sessionId != null &&
      !widget.sessionId!.startsWith('solo_');

  // Phase 6: timer and stats
  bool _timerEnabled = false;
  bool _statsEnabled = false;
  Timer? _readingTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressRepo = widget.readingProgressRepository ?? getIt<ReadingProgressRepository>();
    _deviceService = widget.deviceService ?? getIt<DeviceService>();
    _sessionRepo = widget.sessionRepository ?? getIt<SessionRepository>();
    _readingTimeRepo = widget.readingTimeRepository ??
        (getIt.isRegistered<ParticipantReadingTimeRepository>()
            ? getIt<ParticipantReadingTimeRepository>() : null);
    _contentSync = widget.contentSync;

    _totalPages = widget.book.pageCount > 0 ? widget.book.pageCount : 1;
    _activeSessionId = widget.sessionId ?? 'solo_${widget.book.id}';

    _initializeReader();
    _setupLanSyncSubscriptions();
  }

  void _setupLanSyncSubscriptions() {
    if (!widget.isHost && widget.participantClient != null) {
      _participantPageSub = widget.participantClient!.pageStream.listen((syncedPage) {
        if (!mounted || _sessionStatus == 'ended' || _sessionStatus == 'saved') return;
        final client = widget.participantClient!;
        final newTotal = client.totalPages;
        final shouldUpdatePage = syncedPage != _currentPage;
        final shouldUpdateTotal = newTotal != _totalPages && newTotal > 0;

        if (shouldUpdatePage || shouldUpdateTotal) {
          setState(() {
            if (shouldUpdatePage) {
              _currentPage = syncedPage.clamp(1, newTotal > 0 ? newTotal : _totalPages);
              _highlightMode = false;
            }
            if (shouldUpdateTotal) {
              _totalPages = newTotal;
            }
          });
          _saveProgress();
        }
      });

      _participantStatusSub = widget.participantClient!.statusStream.listen((status) async {
        if (!mounted) return;
        final client = widget.participantClient!;
        setState(() {
          _sessionStatus = status;
          if (client.totalPages > 0) _totalPages = client.totalPages;
          if (client.currentPage > 0) {
            _currentPage = client.currentPage.clamp(1, _totalPages);
          }
        });
        if (status == 'ended') {
          _stopActivityTimer();
          _readingTimer?.cancel();
          await _lastActivityWrite.catchError((_) {});
          await _sessionRepo.endReadingSession(_activeSessionId);
          if (_statsEnabled && mounted) await _showEndStats();
        } else if (status == 'saved') {
          _stopActivityTimer();
          _readingTimer?.cancel();
          await _lastActivityWrite.catchError((_) {});
          await _sessionRepo.saveAndLeaveSession(
            _activeSessionId, lastPage: _currentPage, totalPages: _totalPages,
          );
        } else if (status == 'active' || status == 'paused') {
          if (status == 'paused') {
            _stopActivityTimer();
            _readingTimer?.cancel();
          } else {
            _startTimerIfEnabled();
          }
          await _sessionRepo.updateSessionStatus(_activeSessionId, status);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _participantPageSub?.cancel();
    _participantStatusSub?.cancel();
    _stopActivityTimer();
    _readingTimer?.cancel();
    if (_ownsContentSync && _contentSync != null) {
      unawaited(_contentSync!.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimerIfEnabled();
    } else {
      // Leaving the foreground never changes the SQLite session to ended.
      _readingTimer?.cancel();
      _stopActivityTimer();
      unawaited(_saveProgress());
    }
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
      _displayName = profile.displayName;

      var existingSession = await _sessionRepo.getSessionById(_activeSessionId);
      // Library is always a local reading flow, not a shortcut into a saved
      // session. My Sessions -> Resume reopens that same saved session instead.
      if (widget.sessionId == null &&
          (existingSession?.status == 'ended' || existingSession?.status == 'saved')) {
        _activeSessionId = 'solo_${widget.book.id}_${DateTime.now().microsecondsSinceEpoch}';
        existingSession = null;
      }
      if (!mounted) return;
      if (existingSession == null) {
        await _sessionRepo.createSession(
          id: _activeSessionId,
          title: _isGroup ? 'Room Session' : 'Personal Reading',
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

      final previousTime = await _readingTimeRepo?.getTime(_activeSessionId, _deviceId);
      _elapsedSeconds = previousTime?.totalSeconds ?? 0;

      ReadingProgress? savedProgress =
          await _progressRepo.getProgress(_activeSessionId, _deviceId);
      // A newly created group room starts at page 1, not another room's page.
      if (savedProgress == null && _activeSessionId.startsWith('solo_')) {
        savedProgress = await _progressRepo.getLatestBookProgress(widget.book.id, _deviceId);
      }

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

      // Do not overwrite saved participant progress with the client's default
      // page 1 while the new LAN join is still waiting for its snapshot.
      final client = widget.participantClient;
      if (!widget.isHost && client != null) {
        if (client.hasSnapshot) {
          if (client.totalPages > 0) _totalPages = client.totalPages;
          _currentPage = client.currentPage.clamp(1, _totalPages);
          _sessionStatus = client.sessionStatus;
        } else if (client.sessionStatus == 'saved' || client.sessionStatus == 'ended') {
          _sessionStatus = client.sessionStatus;
        }
      }

      if (widget.showLegacySessionContent) await _attachContentSync();
      if (mounted && (widget.isHost || client == null || client.hasSnapshot)) {
        await _saveProgress();
      }
      if (widget.isHost && widget.hostServer?.isRunning == true &&
          (widget.hostServer!.currentPage != _currentPage ||
              widget.hostServer!.totalPages != _totalPages)) {
        widget.hostServer!.broadcastPageChange(_currentPage, _totalPages);
      }
      _startTimerIfEnabled();

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

  Future<void> _attachContentSync() async {
    if (_contentSync != null || !mounted) return;
    final content = widget.contentRepository ??
        (getIt.isRegistered<SessionContentRepository>()
            ? getIt<SessionContentRepository>() : null);
    final files = widget.voiceStore ??
        (getIt.isRegistered<SessionVoiceStore>() ? getIt<SessionVoiceStore>() : null);
    if (content == null || files == null) return;
    final profile = await _deviceService.getOrCreateCurrentProfile();
    if (!mounted) return;
    _contentSync = SessionContentSync(
      sessionId: _activeSessionId, bookId: widget.book.id,
      deviceId: _deviceId, displayName: profile.displayName,
      totalPages: _totalPages, repository: content, voiceStore: files,
      progressRepository: _progressRepo,
      readingTimeRepository: _readingTimeRepo,
      host: widget.isHost ? widget.hostServer : null,
      participant: widget.isHost ? null : widget.participantClient,
    )..start();
    _ownsContentSync = true;
  }

  void _startTimerIfEnabled() {
    if (!_canTurnPage || !mounted) return;
    _startActivityTimer();
    if (!_timerEnabled) return;
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _startActivityTimer() {
    if (_readingTimeRepo == null || _deviceId.isEmpty || _activityTimer != null ||
        !_canTurnPage) return;
    _lastActivityAt = DateTime.now();
    _activityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _recordElapsedTime();
    });
  }

  void _recordElapsedTime() {
    final previous = _lastActivityAt;
    final repo = _readingTimeRepo;
    if (previous == null || repo == null || _deviceId.isEmpty) return;
    final now = DateTime.now();
    final seconds = now.difference(previous).inSeconds;
    if (seconds <= 0) return;
    _lastActivityAt = previous.add(Duration(seconds: seconds));
    if (!_timerEnabled && mounted) setState(() => _elapsedSeconds += seconds);
    final session = _activeSessionId;
    final device = _deviceId;
    _lastActivityWrite = _lastActivityWrite.catchError((_) {}).then((_) async {
      final persisted = await repo.addReadingTime(id: 'time_${session}_$device',
          sessionId: session, deviceId: device,
          additionalSeconds: seconds);
      if (!widget.isHost && _contentSync != null) {
        unawaited(_contentSync!.reportReadingTime(persisted.totalSeconds)
            .catchError((_) {}));
      }
    });
    // The explicit leave flow awaits the write; background/lifecycle writes
    // still need a handled error when there is no awaiter.
    unawaited(_lastActivityWrite.catchError((_) {}));
  }

  void _stopActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _recordElapsedTime();
    _lastActivityAt = null;
  }

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _saveProgress({bool requireSuccess = false}) {
    if (_deviceId.isEmpty) {
      if (requireSuccess) {
        return Future<void>.error(StateError('Reading session is not ready yet.'));
      }
      return Future<void>.value();
    }
    // A rapid 1 -> 2 -> 5 -> 10 sequence must not finish an older async DB
    // write after the final Save and Leave write, reverting the saved page.
    final page = _currentPage;
    final total = _totalPages;
    final sessionId = _activeSessionId;
    final deviceId = _deviceId;
    _lastProgressWrite = _lastProgressWrite.catchError((_) {}).then((_) async {
      try {
        final progressId = 'prog_${sessionId}_${widget.book.id}_$deviceId';
        await _progressRepo.updateProgress(
          id: progressId,
          sessionId: sessionId,
          bookId: widget.book.id,
          deviceId: deviceId,
          currentPage: page,
          totalPages: total,
        );
        final updated = await _sessionRepo.updateSessionLastPage(sessionId, page, total);
        if (!updated && requireSuccess) {
          throw StateError('Reading session is no longer available.');
        }
        if (updated && !widget.isHost && _contentSync != null) {
          unawaited(_contentSync!.reportProgress(page, total).catchError((_) {}));
        }
      } catch (_) {
        if (requireSuccess) rethrow;
      }
    });
    return _lastProgressWrite;
  }

  void previousPage() {
    if (!_canTurnPage) return;
    if (!widget.isHost && _isGroup) return;
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _highlightMode = false;
      });
      _saveProgress();
      if (widget.isHost) {
        widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
      }
    }
  }

  void nextPage() {
    if (!_canTurnPage) return;
    if (!widget.isHost && _isGroup) return;
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
        _highlightMode = false;
      });
      _saveProgress();
      if (widget.isHost) {
        widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
      }
    }
  }

  void goToPage(int page) {
    if (!_canTurnPage) return;
    if (!widget.isHost && _isGroup) return;
    final targetPage = page.clamp(1, _totalPages);
    if (targetPage != _currentPage) {
      setState(() {
        _currentPage = targetPage;
        _highlightMode = false;
      });
      _saveProgress();
      if (widget.isHost) {
        widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
      }
    }
  }

  Future<void> _toggleGroupPause() async {
    if (!widget.isHost || !_isGroup ||
        (_sessionStatus != 'active' && _sessionStatus != 'paused')) return;
    final pause = _sessionStatus == 'active';
    try {
      final updated = await _sessionRepo.updateSessionStatus(
        _activeSessionId, pause ? 'paused' : 'active',
      );
      if (!updated) throw StateError('Reading session is no longer available.');
      if (pause) {
        widget.hostServer?.broadcastSessionPaused();
        _stopActivityTimer();
        _readingTimer?.cancel();
      } else {
        widget.hostServer?.broadcastSessionResumed();
      }
      if (mounted) setState(() => _sessionStatus = pause ? 'paused' : 'active');
      if (!pause) _startTimerIfEnabled();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
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
            if (widget.isHost) ...[
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
            ],
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
      return _handleSaveAndLeave();
    } else if (result == 'end' && widget.isHost) {
      final confirmed = await _showEndConfirmation();
      if (confirmed) return _handleEndReadingSession();
    }
    return false;
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

  Future<bool> _handleSaveAndLeave() async {
    _stopActivityTimer();
    try {
      await _lastActivityWrite;
      await _saveProgress(requireSuccess: true);
      final saved = await _sessionRepo.saveAndLeaveSession(
        _activeSessionId, lastPage: _currentPage, totalPages: _totalPages,
      );
      if (!saved) throw StateError('Session could not be saved.');
      if (widget.isHost && widget.hostServer != null) {
        widget.onLanSessionClosed?.call();
        widget.hostServer!.broadcastSessionSaved();
        await widget.hostServer!.stop();
      } else if (widget.participantClient != null) {
        await widget.participantClient!.disconnect();
      }
      _readingTimer?.cancel();
      if (mounted) setState(() => _sessionStatus = 'saved');
      return true;
    } catch (e) {
      _startTimerIfEnabled();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).failedToSaveSession}: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }
  }

  Future<bool> _handleEndReadingSession() async {
    if (!widget.isHost) return false;
    _stopActivityTimer();
    try {
      await _lastActivityWrite;
      await _saveProgress(requireSuccess: true);
      final ended = await _sessionRepo.endReadingSession(_activeSessionId);
      if (!ended) throw StateError('Session could not be ended.');
      if (widget.hostServer != null) {
        widget.onLanSessionClosed?.call();
        widget.hostServer!.broadcastSessionEnded();
        await widget.hostServer!.stop();
      }
      _readingTimer?.cancel();
      if (mounted) setState(() => _sessionStatus = 'ended');
      if (_statsEnabled && mounted) await _showEndStats();
      return true;
    } catch (e) {
      _startTimerIfEnabled();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${AppLocalizations.of(context).failedToEndSession}: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }
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
            Text('${l10n.tr('readTime')}: ${_formatElapsed(_elapsedSeconds)}'),
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

  Future<void> _openContentPanel() async {
    final sync = _contentSync;
    if (sync == null) return;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: SizedBox(
            height: (MediaQuery.sizeOf(ctx).height - inset) * 0.78,
            child: SessionContentPanel(
              sync: sync, pageNumber: _currentPage,
              canEdit: _canTurnPage, isGroup: _isGroup,
              audioService: widget.audioService,
            ),
          ),
        );
      },
    );
  }

  Future<void> _chooseHighlight() async {
    if (_contentSync == null || !_canTurnPage) return;
    if (_highlightMode) {
      setState(() => _highlightMode = false);
      return;
    }
    bool? shared = false;
    if (_isGroup) {
      final l10n = AppLocalizations.of(context);
      shared = await showModalBottomSheet<bool>(context: context,
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.tr('personalNote')),
              onTap: () => Navigator.pop(ctx, false)),
            ListTile(title: Text(l10n.tr('sharedNote')),
              onTap: () => Navigator.pop(ctx, true)),
          ])));
    }
    if (!mounted || shared == null) return;
    setState(() { _highlightShared = shared!; _highlightMode = true; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).tr('highlightHint'))));
  }

  Future<void> _persistHighlight(Rect area) async {
    if (!_canTurnPage || _contentSync == null) return;
    try {
      await _contentSync!.addHighlight(_currentPage, area.left, area.top,
          area.width, area.height, shared: _highlightShared);
      if (mounted) setState(() => _highlightMode = false);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppLocalizations.of(context).tr('contentFailed')}: $error'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _exitApproved || _sessionStatus == 'saved' || _sessionStatus == 'ended',
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _leaveInProgress) return;
        _leaveInProgress = true;
        try {
          final shouldPop = _sessionStatus == 'saved' || _sessionStatus == 'ended'
              ? true
              : await _showLeaveDialog();
          if (shouldPop && mounted) {
            setState(() => _exitApproved = true);
            Navigator.pop(context);
          }
        } finally {
          _leaveInProgress = false;
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
              if (_isGroup)
                Text(
                  '${l10n.roomCode}: ${widget.sessionId}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                ),
            ],
          ),
          actions: [
            if (widget.showLegacySessionContent && _contentSync != null) ...[
              IconButton(key: const Key('reader_notes_discussion'),
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: l10n.tr('notesDiscussion'),
                onPressed: _isLoading || _errorMessage != null
                    ? null : _openContentPanel),
              IconButton(key: const Key('reader_highlight'),
                icon: Icon(_highlightMode ? Icons.brush : Icons.brush_outlined),
                tooltip: l10n.tr('highlightPage'),
                onPressed: _isLoading || _errorMessage != null || !_canTurnPage
                    ? null : _chooseHighlight),
            ],
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
            if (widget.isHost && _isGroup &&
                (_sessionStatus == 'active' || _sessionStatus == 'paused'))
              IconButton(
                key: Key(_sessionStatus == 'paused'
                    ? 'resume_reader_session_button' : 'pause_reader_session_button'),
                icon: _sessionStatus == 'paused' ? AppIcon.play() : AppIcon.pause(),
                tooltip: _sessionStatus == 'paused' ? l10n.resume : l10n.pause,
                onPressed: _isLoading || _errorMessage != null ? null : _toggleGroupPause,
              ),
            IconButton(
              icon: AppIcon.bookmark(),
              tooltip: l10n.jumpToPage,
              onPressed: _isLoading || _errorMessage != null || !_canTurnPage ||
                      (!widget.isHost && _isGroup)
                  ? null : _showJumpToPageDialog,
            ),
          ],
        ),
        body: _buildBody(),
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

    final isParticipantMode = !widget.isHost && _isGroup;

    // Both pdfx and the message list scroll internally. Bound their heights so
    // neither receives unbounded constraints, and let the reader as a whole
    // scroll when the viewport is short (landscape / on-screen keyboard).
    // Keeping the same subtree in both layouts also preserves the pdfx viewer
    // state when the keyboard opens or a message is sent.
    return LayoutBuilder(
      builder: (context, constraints) {
        const navigationAndProgressHeight = 76.0;
        final remainingHeight = math.max(
          0.0, constraints.maxHeight - navigationAndProgressHeight);
        // Keep the page controls reachable even in landscape/with the IME.
        // In an exceptionally short viewport, reduce the PDF further so the
        // user can start scrolling from a visible part of the controls.
        final minPdfHeight = constraints.maxHeight < 400
            ? math.min(160.0, math.max(80.0,
                constraints.maxHeight - navigationAndProgressHeight - 20.0))
            : 240.0;
        final pdfHeight = math.max(minPdfHeight, remainingHeight * 0.56);
        final messagesHeight = math.max(240.0, remainingHeight * 0.44);

        return SingleChildScrollView(
          key: const Key('reader_vertical_scroll'),
          child: Column(
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
              if (_sessionStatus == 'saved')
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Center(child: Text(l10n.savedStatus)),
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
              if (widget.showLegacySessionContent && _contentSync != null && _deviceId.isNotEmpty)
                StreamBuilder<List<SessionAnnotation>>(
                  stream: _contentSync!.repository.watchAnnotations(
                      _activeSessionId, _currentPage, _deviceId),
                  builder: (context, snapshot) {
                    final pinned = snapshot.data?.where((n) => n.isPinned).toList() ?? [];
                    if (pinned.isEmpty) return const SizedBox.shrink();
                    return SizedBox(height: 48, child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: pinned.map((note) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          label: SizedBox(width: MediaQuery.sizeOf(context).width * 0.58,
                            child: Text('📌 ${note.content}', maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                          onPressed: _openContentPanel,
                        ),
                      )).toList(),
                    ));
                  },
                ),
              SizedBox(
                height: pdfHeight,
                child: _sessionStatus == 'ended'
                    ? Center(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(mainAxisSize: MainAxisSize.min,
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
                        ),
                      )
                    : _buildAnnotatedPage(isParticipantMode),
              ),
              // Solo and Group share one offline, page-scoped text/audio
              // discussion. Its streams and player never recreate PdfPageView.
              _buildBottomBar(),
              SizedBox(
                height: messagesHeight,
                child: TextMessagesPanel(
                  sessionId: _activeSessionId,
                  pageNumber: _currentPage,
                  senderId: _deviceId,
                  senderName: _displayName,
                  canSend: _canTurnPage,
                  controller: widget.textMessagesController,
                  audioRepository: widget.audioMessageRepository,
                  audioService: widget.messageAudioService,
                  voiceStore: widget.voiceStore,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnnotatedPage(bool isParticipantMode) {
    Widget makePage(List<SessionAnnotation> highlights) => IgnorePointer(
      ignoring: !_canTurnPage || (isParticipantMode && !_highlightMode),
      child: PdfPageView(
        filePath: widget.book.filePath, pageNumber: _currentPage,
        totalPages: _totalPages, bookTitle: widget.book.title,
        author: widget.book.author, highlights: highlights,
        highlightMode: _highlightMode && _canTurnPage,
        onHighlightSelected: (area) => unawaited(_persistHighlight(area)),
        onPageChanged: (page) {
          if (widget.isHost && _canTurnPage && page != _currentPage) {
            setState(() { _currentPage = page; _highlightMode = false; });
            _saveProgress();
            widget.hostServer?.broadcastPageChange(_currentPage, _totalPages);
          }
        },
      ),
    );
    final sync = widget.showLegacySessionContent ? _contentSync : null;
    if (sync == null || _deviceId.isEmpty) return makePage(const []);
    return StreamBuilder<List<SessionAnnotation>>(
      stream: sync.repository.watchAnnotations(_activeSessionId,
          _currentPage, _deviceId, kind: 'highlight'),
      builder: (context, snapshot) => makePage(snapshot.data ?? const []),
    );
  }

  Future<void> _toggleReadingOption(String option) async {
    if (!_canTurnPage) return;
    try {
      if (option == 'timer') {
        final enabled = !_timerEnabled;
        if (!await _sessionRepo.updateSessionFlags(_activeSessionId,
            timerEnabled: enabled)) throw StateError('Session unavailable');
        if (!mounted) return;
        setState(() => _timerEnabled = enabled);
        if (enabled) _startTimerIfEnabled();
        else _readingTimer?.cancel();
      } else if (option == 'stats') {
        final enabled = !_statsEnabled;
        if (!await _sessionRepo.updateSessionFlags(_activeSessionId,
            statsEnabled: enabled)) throw StateError('Session unavailable');
        if (mounted) setState(() => _statsEnabled = enabled);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppLocalizations.of(context).tr('contentFailed')}: $error'),
      ));
    }
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context);
    final isParticipantMode = !widget.isHost && _isGroup;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(top: false, bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              key: const Key('prev_page_button'),
              icon: isRtl ? const AppIcon.forward(size: 32)
                  : const AppIcon.back(size: 32),
              onPressed: !isParticipantMode && _canTurnPage && _currentPage > 1 ? previousPage : null,
              tooltip: isParticipantMode ? l10n.waitingForParticipants : l10n.tr('previousPage'),
            ),
            Expanded(child: InkWell(
              onTap: isParticipantMode || !_canTurnPage ? null : _showJumpToPageDialog,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    if (isParticipantMode) ...[
                      AppIcon.refresh(size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                    ],
                    Expanded(child: Text(
                      isParticipantMode
                          ? l10n.syncedPage(_currentPage, _totalPages)
                          : l10n.pageOf(_currentPage, _totalPages),
                      key: const Key('page_number_display'),
                      textAlign: TextAlign.center, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isParticipantMode ? const Color(0xFF047857) : const Color(0xFF1E293B),
                      ),
                    )),
                  ],
                ),
              ),
            )),
            IconButton(
              key: const Key('next_page_button'),
              icon: isRtl ? const AppIcon.back(size: 32)
                  : const AppIcon.forward(size: 32),
              onPressed: !isParticipantMode && _canTurnPage && _currentPage < _totalPages ? nextPage : null,
              tooltip: isParticipantMode ? l10n.waitingForParticipants : l10n.tr('nextPage'),
            ),
            PopupMenuButton<String>(
              key: const Key('reader_timer_stats_menu'),
              icon: const Icon(Icons.more_time),
              tooltip: l10n.tr('readTime'),
              enabled: _canTurnPage,
              onSelected: _toggleReadingOption,
              itemBuilder: (_) => [
                CheckedPopupMenuItem(value: 'timer', checked: _timerEnabled,
                    child: Text(l10n.enableTimerLabel)),
                CheckedPopupMenuItem(value: 'stats', checked: _statsEnabled,
                    child: Text(l10n.enableStatsLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
