import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:readmesh/data/repositories/audio_message_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/audio_messages/data/local_audio_service.dart';
import 'package:readmesh/features/audio_messages/domain/audio_message.dart';
import 'package:readmesh/features/audio_messages/presentation/audio_clip_player.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/features/text_messages/domain/text_message.dart';
import 'text_messages_controller.dart';

/// Inline, bounded discussion under the PDF/page controls. Only this widget
/// rebuilds for message changes; the reader's pdfx view is a sibling.
class TextMessagesPanel extends StatefulWidget {
  final String sessionId;
  final int pageNumber;
  final String senderId;
  final String senderName;
  final bool canSend;
  final TextMessagesController? controller;
  final AudioMessageRepository? audioRepository;
  final LocalAudioService? audioService;
  final SessionVoiceStore? voiceStore;

  const TextMessagesPanel({super.key, required this.sessionId,
    required this.pageNumber, required this.senderId, required this.senderName,
    required this.canSend, this.controller, this.audioRepository,
    this.audioService, this.voiceStore});

  @override
  State<TextMessagesPanel> createState() => _TextMessagesPanelState();
}

enum AudioComposerMode { text, recording, paused, preview }

class _TextMessagesPanelState extends State<TextMessagesPanel> {
  final TextEditingController _draft = TextEditingController();
  final TextEditingController _editDraft = TextEditingController();
  final ScrollController _scroll = ScrollController();
  TextMessagesController? _controller;
  late Stream<List<TextMessage>> _pageMessages;
  bool _busy = false;
  bool _showEmoji = false;
  final Map<int, String> _pageDrafts = {};
  String? _lastMessageId;
  String? _editingId;
  int _streamRevision = 0;

  AudioMessageRepository? _audioRepository;
  LocalAudioService? _audioService;
  SessionVoiceStore? _voiceStore;
  late Stream<List<AudioMessage>> _pageAudio;
  AudioComposerMode _audioMode = AudioComposerMode.text;
  File? _draftAudio;
  String? _draftAudioId;
  String? _draftSessionId;
  int? _draftPage;
  AudioMessage? _replacingAudio;
  int _durationMs = 0;
  bool _audioBusy = false;
  int _audioGeneration = 0;
  final Stopwatch _recordingClock = Stopwatch();
  Timer? _recordingTick;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraftChanged);
    _bindController();
    _bindAudio();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _retry() {
    setState(() {
      _streamRevision++;
      _bindController();
      _bindAudio();
    });
  }

  void _bindController() {
    // The panel must never disappear when the data layer is unavailable.
    // Production registers MessageRepository in setupLocator before runApp;
    // an incomplete bootstrap instead renders an actionable error state.
    final repository = getIt.isRegistered<MessageRepository>()
        ? getIt<MessageRepository>() : null;
    _controller = widget.controller ?? (repository == null ? null
        : TextMessagesController(
            repository: repository,
            sessionId: widget.sessionId,
            senderId: widget.senderId,
            senderName: widget.senderName,
          ));
    _pageMessages = _controller?.watchPage(widget.pageNumber) ??
        Stream<List<TextMessage>>.error(
            StateError('Local message repository is not registered'));
    _lastMessageId = null;
  }

  void _bindAudio() {
    _audioRepository = widget.audioRepository ??
        (getIt.isRegistered<AudioMessageRepository>()
            ? getIt<AudioMessageRepository>() : null);
    _audioService = widget.audioService ??
        (getIt.isRegistered<LocalAudioService>()
            ? getIt<LocalAudioService>() : null);
    _voiceStore = widget.voiceStore ??
        (getIt.isRegistered<SessionVoiceStore>()
            ? getIt<SessionVoiceStore>() : null);
    _pageAudio = _audioRepository?.watchPage(
          widget.sessionId, widget.pageNumber) ??
        Stream.value(const <AudioMessage>[]);
    _lastMessageId = null;
  }

  bool get _canRecord => widget.canSend && _controller != null &&
      _audioRepository != null && _audioService != null &&
      _voiceStore != null && !_audioBusy && !_busy;

  @override
  void didUpdateWidget(covariant TextMessagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId ||
        widget.senderId != oldWidget.senderId ||
        widget.senderName != oldWidget.senderName ||
        widget.controller != oldWidget.controller ||
        widget.audioRepository != oldWidget.audioRepository ||
        widget.audioService != oldWidget.audioService ||
        widget.voiceStore != oldWidget.voiceStore) {
      _onContextChanged();
      _pageDrafts.clear();
      _draft.removeListener(_onDraftChanged);
      _draft.clear();
      _draft.addListener(_onDraftChanged);
      _editingId = null;
      _bindController();
      _bindAudio();
    } else if (widget.pageNumber != oldWidget.pageNumber) {
      _onContextChanged();
      // Keep unsent drafts on their own page; never send an old-page draft
      // under the newly visible pageNumber.
      _pageDrafts[oldWidget.pageNumber] = _draft.text;
      final nextDraft = _pageDrafts[widget.pageNumber] ?? '';
      _draft.removeListener(_onDraftChanged);
      _draft.value = TextEditingValue(text: nextDraft,
        selection: TextSelection.collapsed(offset: nextDraft.length));
      _draft.addListener(_onDraftChanged);
      // Replacing the stream, not adding another subscription, prevents
      // messages from the previous page appearing during navigation.
      _editingId = null;
      _pageMessages = _controller?.watchPage(widget.pageNumber) ??
          Stream<List<TextMessage>>.error(
              StateError('Local message repository is not registered'));
      _pageAudio = _audioRepository?.watchPage(widget.sessionId,
            widget.pageNumber) ?? Stream.value(const <AudioMessage>[]);
      _lastMessageId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    } else if (oldWidget.canSend && !widget.canSend) {
      // Pausing/ending the session must not leave a live microphone behind.
      _onContextChanged();
    }
  }

  void _onContextChanged() {
    // A draft belongs to the page on which recording began. Navigating to
    // another page must never publish it under the new page's identity.
    _audioGeneration++;
    final oldMode = _audioBusy && _audioMode == AudioComposerMode.text &&
        _draftAudio != null ? AudioComposerMode.recording : _audioMode;
    final oldFile = _draftAudio;
    final oldService = _audioService;
    _recordingTick?.cancel();
    _recordingClock.stop();
    _recordingClock.reset();
    _audioMode = AudioComposerMode.text;
    _draftAudio = null;
    _draftAudioId = null;
    _draftPage = null;
    _draftSessionId = null;
    _replacingAudio = null;
    _durationMs = 0;
    if (oldFile != null &&
        !(_audioBusy && oldMode == AudioComposerMode.preview)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_cleanupDraft(oldFile, oldService, oldMode)
            .catchError((_) {}));
      });
    }
  }

  Future<void> _cleanupDraft(File file, LocalAudioService? service,
      AudioComposerMode mode) async {
    if (mode == AudioComposerMode.recording ||
        mode == AudioComposerMode.paused) {
      try { await service?.cancel(); } catch (_) {}
    }
    try { await service?.stopPlayback(file.path); } catch (_) {}
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    _recordingTick?.cancel();
    _audioGeneration++;
    final file = _draftAudio;
    final mode = _audioBusy && _audioMode == AudioComposerMode.text &&
        file != null ? AudioComposerMode.recording : _audioMode;
    if (file != null &&
        !(_audioBusy && mode == AudioComposerMode.preview)) {
      unawaited(_cleanupDraft(file, _audioService, mode)
          .catchError((_) {}));
    }
    _draft.removeListener(_onDraftChanged);
    _draft.dispose();
    _editDraft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${AppLocalizations.of(context).tr('textMessageError')}: $error'),
      backgroundColor: Colors.red,
    ));
  }

  void _toNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final controller = _controller;
    if (controller == null || !widget.canSend || _busy || _audioBusy ||
        _audioMode != AudioComposerMode.text ||
        _draft.text.trim().isEmpty) return;
    // Capture page before awaiting SQLite, so navigation during an insert
    // cannot misattribute a message to the newly visible page.
    final page = widget.pageNumber;
    final text = _draft.text;
    setState(() => _busy = true);
    try {
      await controller.send(page, text);
      if (!mounted) return;
      if (_pageDrafts[page] == text) _pageDrafts.remove(page);
      if (widget.pageNumber == page && _draft.text == text) _draft.clear();
      _toNewest();
    } catch (error) {
      _error(error); // Keep the unsent draft for retry.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(TextMessage message) async {
    final controller = _controller;
    if (controller == null || _busy || _editDraft.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      if (!await controller.edit(message, _editDraft.text)) {
        throw StateError('Message not found or sender does not match');
      }
      if (mounted) setState(() => _editingId = null);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(TextMessage message) async {
    final controller = _controller;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (!await controller.delete(message)) {
        throw StateError('Message not found or sender does not match');
      }
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startRecordingTick() {
    _recordingTick?.cancel();
    _recordingTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _audioMode != AudioComposerMode.recording) return;
      setState(() => _durationMs =
          _recordingClock.elapsedMilliseconds.clamp(0, 65000).toInt());
      if (_durationMs >= 60000 && !_audioBusy) unawaited(_stopRecording());
    });
  }

  Future<void> _startRecording({AudioMessage? replacing}) async {
    if (!_canRecord || _audioMode != AudioComposerMode.text ||
        (replacing == null && _draft.text.trim().isNotEmpty)) return;
    final service = _audioService!;
    final files = _voiceStore!;
    final session = widget.sessionId;
    final page = widget.pageNumber;
    final deniedMessage = AppLocalizations.of(context).tr('audioPermissionDenied');
    final id = 'audio_${const Uuid().v4()}';
    final token = ++_audioGeneration;
    setState(() => _audioBusy = true);
    File? file;
    try {
      file = await files.fileFor(session, 'draft_$id');
      if (!mounted || token != _audioGeneration) {
        if (await file.exists()) await file.delete();
        return;
      }
      _draftAudio = file;
      _draftAudioId = id;
      _draftSessionId = session;
      _draftPage = page;
      _replacingAudio = replacing;
      if (replacing != null) await service.stopPlayback(replacing.audioPath);
      final started = await service.start(file.path);
      if (!started) {
        throw StateError(deniedMessage);
      }
      if (!mounted || token != _audioGeneration) {
        await _cleanupDraft(file, service, AudioComposerMode.recording);
        return;
      }
      _recordingClock.reset();
      _recordingClock.start();
      setState(() { _audioMode = AudioComposerMode.recording; _durationMs = 0; });
      _startRecordingTick();
    } catch (error) {
      if (file != null) {
        try { await _cleanupDraft(file, service, AudioComposerMode.recording); }
        catch (_) {}
      }
      if (mounted && token == _audioGeneration) {
        setState(() {
          _audioMode = AudioComposerMode.text;
          _draftAudio = null;
          _draftAudioId = null;
          _draftSessionId = null;
          _draftPage = null;
          _replacingAudio = null;
          _durationMs = 0;
        });
        _audioError(error);
      }
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<void> _pauseRecording() async {
    if (_audioMode != AudioComposerMode.recording || _audioBusy) return;
    final token = _audioGeneration;
    setState(() => _audioBusy = true);
    try {
      await _audioService!.pauseRecording();
      if (!mounted || token != _audioGeneration) return;
      _recordingClock.stop();
      _recordingTick?.cancel();
      setState(() {
        _durationMs = _recordingClock.elapsedMilliseconds;
        _audioMode = AudioComposerMode.paused;
      });
    } catch (error) {
      // On Android < 24 pause is unsupported; recording continues in the
      // existing file rather than silently starting a new one.
      _audioError(error);
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<void> _resumeRecording() async {
    if (_audioMode != AudioComposerMode.paused || _audioBusy) return;
    final token = _audioGeneration;
    setState(() => _audioBusy = true);
    try {
      await _audioService!.resumeRecording();
      if (!mounted || token != _audioGeneration) return;
      _recordingClock.start();
      setState(() => _audioMode = AudioComposerMode.recording);
      _startRecordingTick();
    } catch (error) {
      _audioError(error);
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_audioBusy ||
        (_audioMode != AudioComposerMode.recording &&
         _audioMode != AudioComposerMode.paused)) return;
    final file = _draftAudio;
    final token = _audioGeneration;
    if (file == null) return;
    _recordingTick?.cancel();
    _recordingClock.stop();
    setState(() => _audioBusy = true);
    try {
      final duration = await _audioService!.stop();
      await _voiceStore!.inspect(file); // reject empty/oversized/corrupt files
      if (!mounted || token != _audioGeneration) {
        if (await file.exists()) await file.delete();
        return;
      }
      if (duration < 1) throw StateError('Empty recording');
      setState(() {
        _durationMs = duration;
        _audioMode = AudioComposerMode.preview;
      });
    } catch (error) {
      try { await _cleanupDraft(file, _audioService, _audioMode); }
      catch (_) {}
      if (mounted && token == _audioGeneration) {
        setState(() {
          _audioMode = AudioComposerMode.text;
          _draftAudio = null;
          _draftAudioId = null;
          _draftSessionId = null;
          _draftPage = null;
          _replacingAudio = null;
          _durationMs = 0;
        });
        _audioError(error);
      }
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<void> _cancelAudio() async {
    final file = _draftAudio;
    if (file == null || _audioBusy) return;
    final mode = _audioMode;
    final service = _audioService;
    _audioGeneration++;
    _recordingTick?.cancel();
    _recordingClock.stop();
    _recordingClock.reset();
    setState(() {
      _audioMode = AudioComposerMode.text;
      _draftAudio = null;
      _draftAudioId = null;
      _draftSessionId = null;
      _draftPage = null;
      _replacingAudio = null;
      _durationMs = 0;
    });
    try { await _cleanupDraft(file, service, mode); }
    catch (error) { _audioError(error); }
  }

  Future<void> _sendAudio() async {
    if (_audioMode != AudioComposerMode.preview || _audioBusy ||
        !widget.canSend) return;
    final file = _draftAudio;
    final id = _draftAudioId;
    final session = _draftSessionId;
    final page = _draftPage;
    if (file == null || id == null || session != widget.sessionId ||
        page != widget.pageNumber || _durationMs < 1 ||
        _audioRepository == null) return;
    final token = _audioGeneration;
    final service = _audioService;
    final repository = _audioRepository!;
    final senderId = widget.senderId;
    final senderName = widget.senderName;
    final duration = _durationMs;
    final replacing = _replacingAudio;
    setState(() => _audioBusy = true);
    try {
      await service?.stopPlayback(file.path);
      await repository.send(
        id: id, sessionId: session!, pageNumber: page!,
        senderId: senderId, senderDisplayName: senderName,
        draft: file, durationMs: duration, replacing: replacing,
      );
      if (mounted && token == _audioGeneration) {
        _recordingClock.reset();
        setState(() {
          _audioMode = AudioComposerMode.text;
          _draftAudio = null;
          _draftAudioId = null;
          _draftSessionId = null;
          _draftPage = null;
          _replacingAudio = null;
          _durationMs = 0;
        });
      }
    } catch (error) {
      if (!mounted || token != _audioGeneration) {
        // A failed send to an old page has no longer got a visible preview.
        // Remove the restored draft instead of leaking it until next launch.
        try { await _cleanupDraft(file, service, AudioComposerMode.preview); }
        catch (_) {}
      } else {
        // SQLite failure restores this page's preview for retry or discard.
        _audioError(error);
      }
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<void> _deleteAudio(AudioMessage message) async {
    if (message.senderId != widget.senderId || _audioBusy ||
        _audioRepository == null) return;
    setState(() => _audioBusy = true);
    try {
      await _audioService?.stopPlayback(message.audioPath);
      if (!await _audioRepository!.deleteOwn(message, widget.senderId)) {
        throw StateError('Recording is no longer available');
      }
    } catch (error) {
      _audioError(error);
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Widget _messageTile(TextMessage message, AppLocalizations l10n) {
    final mine = message.senderId == widget.senderId;
    final time = message.createdAt.toLocal();
    final timeLabel = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Card(
      key: Key('text_message_${message.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: mine ? const Color(0xFFEFF6FF) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(message.senderName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB)))),
            if (mine && widget.canSend) ...[
              IconButton(key: Key('edit_message_${message.id}'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: l10n.tr('editTextMessage'),
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => setState(() {
                  _editingId = message.id;
                  _editDraft.text = message.text;
                })),
              IconButton(key: Key('delete_message_${message.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: l10n.delete,
                visualDensity: VisualDensity.compact,
                onPressed: _busy ? null : () => _delete(message)),
            ],
          ]),
          if (_editingId == message.id)
            Row(children: [
              Expanded(child: TextField(key: const Key('edit_text_message'),
                controller: _editDraft, maxLength: 2000,
                decoration: InputDecoration(hintText: l10n.tr('textMessageHint'),
                    counterText: '', isDense: true))),
              IconButton(key: const Key('save_text_message_edit'),
                  icon: const Icon(Icons.check), onPressed: _busy
                      ? null : () => _edit(message)),
              IconButton(icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _editingId = null)),
            ])
          else
            Text(message.text, key: Key('message_body_${message.id}')),
          Align(alignment: AlignmentDirectional.centerEnd,
            child: Text(timeLabel,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
        ]),
      ),
    );
  }

  Widget _audioTile(AudioMessage message, AppLocalizations l10n) {
    final mine = message.senderId == widget.senderId;
    final time = message.createdAt.toLocal();
    final timeLabel = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Card(
      key: Key('audio_message_${message.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: mine ? const Color(0xFFEFF6FF) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(message.senderDisplayName == 'Local reader'
                ? l10n.tr('audioLocalReader') : message.senderDisplayName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB)))),
            if (mine && widget.canSend) ...[
              IconButton(key: Key('replace_audio_${message.id}'),
                icon: const Icon(Icons.mic_none, size: 18),
                tooltip: l10n.tr('audioReplace'),
                visualDensity: VisualDensity.compact,
                onPressed: _canRecord && _audioMode == AudioComposerMode.text
                    ? () => _startRecording(replacing: message) : null),
              IconButton(key: Key('delete_audio_${message.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: l10n.tr('audioDelete'),
                visualDensity: VisualDensity.compact,
                onPressed: _audioMode == AudioComposerMode.text && !_audioBusy
                    ? () => _deleteAudio(message) : null),
            ],
          ]),
          AudioClipPlayer(key: Key('audio_player_${message.id}'),
            id: message.id, path: message.audioPath,
            durationMs: message.durationMs,
            audio: _audioService, onError: _audioError),
          Align(alignment: AlignmentDirectional.centerEnd,
            child: Text(timeLabel, style: const TextStyle(
              fontSize: 11, color: Color(0xFF64748B)))),
        ]),
      ),
    );
  }

  void _audioError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final description = error is PlatformException &&
        error.code == 'PAUSE_UNSUPPORTED'
        ? l10n.tr('audioPauseUnsupported')
        : '${l10n.tr('audioMessageError')}: $error';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(description), backgroundColor: Colors.red,
    ));
  }

  Widget _composer(AppLocalizations l10n) {
    if (_audioMode != AudioComposerMode.text) {
      final preview = _audioMode == AudioComposerMode.preview;
      return SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.mic, size: 18, color: Color(0xFFDC2626)),
            const SizedBox(width: 7),
            Expanded(child: Text(l10n.tr(preview
                ? (_replacingAudio == null ? 'audioPreview' :
                    'audioReplacePreview')
                : _audioMode == AudioComposerMode.paused
                    ? 'audioPaused' : 'audioRecording'),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(formatAudioDuration(_durationMs),
                key: const Key('audio_recording_timer')),
          ]),
          if (preview && _draftAudio != null && _draftAudioId != null)
            AudioClipPlayer(key: const Key('audio_draft_preview'),
              id: _draftAudioId!, path: _draftAudio!.path,
              durationMs: _durationMs, audio: _audioService,
              onError: _audioError),
          Row(children: [
            IconButton(key: const Key('cancel_audio_recording'),
              tooltip: l10n.tr('audioCancelRecording'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _audioBusy ? null : _cancelAudio),
            const Spacer(),
            if (_audioMode == AudioComposerMode.recording)
              IconButton(key: const Key('pause_audio_recording'),
                tooltip: l10n.tr('audioPauseRecording'),
                icon: const Icon(Icons.pause),
                onPressed: _audioBusy ? null : _pauseRecording),
            if (_audioMode == AudioComposerMode.paused)
              IconButton(key: const Key('resume_audio_recording'),
                tooltip: l10n.tr('audioResumeRecording'),
                icon: const Icon(Icons.play_arrow),
                onPressed: _audioBusy ? null : _resumeRecording),
            if (!preview)
              IconButton(key: const Key('stop_audio_recording'),
                tooltip: l10n.tr('audioStopRecording'),
                icon: const Icon(Icons.stop),
                onPressed: _audioBusy ? null : _stopRecording),
            if (preview)
              TextButton.icon(key: const Key('send_audio_message'),
                onPressed: _audioBusy || !widget.canSend ? null : _sendAudio,
                icon: const Icon(Icons.send),
                label: Text(l10n.tr('audioSend'))),
          ]),
        ]),
      ));
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_showEmoji && widget.canSend && _controller != null)
        SizedBox(height: 40, child: ListView(
          scrollDirection: Axis.horizontal,
          children: ['😊', '👍', '❤️', '😂', '🙏'].map((emoji) =>
            TextButton(onPressed: () => _draft.text += emoji,
              child: Text(emoji))).toList(),
        )),
      SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Row(children: [
          IconButton(key: const Key('text_message_emoji'),
            tooltip: l10n.tr('emoji'),
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: widget.canSend && _controller != null && !_audioBusy
                ? () => setState(() => _showEmoji = !_showEmoji) : null),
          Expanded(child: TextField(
            key: const Key('text_message_input'), controller: _draft,
            enabled: widget.canSend && _controller != null && !_busy &&
                !_audioBusy,
            maxLines: 1, maxLength: 2000,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: l10n.tr('textMessageHint'), counterText: '',
              isDense: true, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          )),
          IconButton(key: const Key('send_text_message_button'),
            icon: Icon(_draft.text.trim().isEmpty
                ? Icons.mic_none : Icons.send),
            tooltip: _draft.text.trim().isEmpty
                ? l10n.tr(_canRecord ? 'audioRecord' : 'voicePlaceholder')
                : l10n.tr('sendMessage'),
            color: const Color(0xFF2563EB),
            onPressed: _draft.text.trim().isEmpty
                ? (_canRecord ? () => _startRecording() : null)
                : (_controller != null && widget.canSend && !_busy &&
                    !_audioBusy ? _send : null)),
        ]),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('text_messages_panel'),
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFCBD5E1)))),
      child: Column(children: [
        Expanded(child: StreamBuilder<List<TextMessage>>(
          key: ValueKey('messages_${widget.sessionId}_${widget.pageNumber}_$_streamRevision'),
          stream: _pageMessages,
          builder: (context, textSnapshot) => StreamBuilder<List<AudioMessage>>(
            key: ValueKey('audio_${widget.sessionId}_${widget.pageNumber}_$_streamRevision'),
            stream: _pageAudio,
            builder: (context, audioSnapshot) {
              final loading = (textSnapshot.connectionState == ConnectionState.waiting &&
                    !textSnapshot.hasData && !textSnapshot.hasError) ||
                  (audioSnapshot.connectionState == ConnectionState.waiting &&
                    !audioSnapshot.hasData && !audioSnapshot.hasError);
              final messages = textSnapshot.data ?? const <TextMessage>[];
              final audio = audioSnapshot.data ?? const <AudioMessage>[];
              final ordered = <Object>[...messages, ...audio]..sort((a, b) {
                final aTime = a is TextMessage ? a.createdAt : (a as AudioMessage).createdAt;
                final bTime = b is TextMessage ? b.createdAt : (b as AudioMessage).createdAt;
                final byTime = aTime.compareTo(bTime);
                if (byTime != 0) return byTime;
                final aOrder = a is TextMessage ? a.localOrder :
                    (a as AudioMessage).localOrder;
                final bOrder = b is TextMessage ? b.localOrder :
                    (b as AudioMessage).localOrder;
                if (aOrder != null && bOrder != null) {
                  return aOrder.compareTo(bOrder);
                }
                final aId = a is TextMessage ? a.id : (a as AudioMessage).id;
                final bId = b is TextMessage ? b.id : (b as AudioMessage).id;
                return aId.compareTo(bId);
              });
              final newest = ordered.isEmpty ? null : ordered.last;
              final lastId = newest is TextMessage ? newest.id :
                  newest is AudioMessage ? newest.id : null;
              if (!textSnapshot.hasError && !audioSnapshot.hasError &&
                  !loading && lastId != _lastMessageId) {
                _lastMessageId = lastId;
                if (lastId != null) _toNewest();
              }
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(children: [
                    const Icon(Icons.chat_bubble_outline, size: 19,
                      color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Flexible(flex: 2, child: Text(l10n.tr(_audioService == null
                        ? 'textMessagesTitle' : 'discussionTab'),
                      key: const Key('text_messages_header'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Text('${ordered.length}', key: const Key('text_message_count'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Flexible(child: Text(l10n.tr('textMessagesLocal'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                  ]),
                ),
                Expanded(child: textSnapshot.hasError || audioSnapshot.hasError
                  ? SingleChildScrollView(key: const Key('text_message_error'),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(l10n.tr(textSnapshot.hasError ? 'textMessageError' :
                            'audioMessageError'), textAlign: TextAlign.center),
                        Text('${textSnapshot.error ?? audioSnapshot.error}',
                          textAlign: TextAlign.center, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                        TextButton(key: const Key('retry_text_messages'),
                          onPressed: _retry, child: Text(l10n.tr('retryMessages'))),
                      ]))
                  : loading
                    ? const Center(child: CircularProgressIndicator(
                        key: Key('text_message_loading')))
                    : ordered.isEmpty
                      ? Center(child: Text(l10n.tr('noPageMessages'),
                          style: const TextStyle(color: Color(0xFF64748B))))
                      : ListView.builder(
                        key: const Key('text_message_list'),
                        controller: _scroll,
                        reverse: true, // newest at the bottom
                        itemCount: ordered.length,
                        itemBuilder: (context, index) {
                          final message = ordered[ordered.length - 1 - index];
                          return message is TextMessage
                              ? _messageTile(message, l10n)
                              : _audioTile(message as AudioMessage, l10n);
                        },
                      )),
              ]);
            },
          ),
        )),
        _composer(l10n),
      ]),
    );
  }
}
