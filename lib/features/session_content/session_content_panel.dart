import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'voice_audio_service.dart';

/// Fixed-height, scrollable page-specific notes and LAN discussion. The
/// existing PdfPageView remains the sole PDF renderer underneath this sheet.
class SessionContentPanel extends StatefulWidget {
  final SessionContentSync sync;
  final int pageNumber;
  final bool canEdit;
  final bool isGroup;
  final VoiceAudioService? audioService;

  const SessionContentPanel({super.key, required this.sync,
    required this.pageNumber, required this.canEdit, required this.isGroup,
    this.audioService});

  @override
  State<SessionContentPanel> createState() => _SessionContentPanelState();
}

class _SessionContentPanelState extends State<SessionContentPanel> {
  final TextEditingController _noteText = TextEditingController();
  final TextEditingController _messageText = TextEditingController();
  final ScrollController _notesScroll = ScrollController();
  final ScrollController _messagesScroll = ScrollController();
  late final VoiceAudioService _audio = widget.audioService ?? AndroidVoiceAudioService();
  StreamSubscription<String>? _errors;
  Timer? _recordingLimit;
  Timer? _recordingTick;
  int _recordingSeconds = 0;
  bool _shared = false;
  bool _saving = false;
  File? _recordingFile;
  String? _recordingId;
  int? _stoppedDurationMs;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _errors = widget.sync.errors.listen((text) => _showError(text));
  }

  @override
  void dispose() {
    _errors?.cancel();
    _recordingLimit?.cancel();
    _recordingTick?.cancel();
    if (_recordingFile != null) unawaited(_audio.cancel());
    unawaited(_audio.stopPlayback());
    _noteText.dispose();
    _messageText.dispose();
    _notesScroll.dispose();
    _messagesScroll.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${l10n.tr('contentFailed')}: $error'),
      backgroundColor: Colors.red,
    ));
  }

  Future<void> _saveNote() async {
    if (!widget.canEdit || _saving || _noteText.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.sync.addNote(widget.pageNumber, _noteText.text,
          shared: widget.isGroup && _shared);
      _noteText.clear();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendText() async {
    if (!widget.canEdit || _saving || _messageText.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.sync.sendText(widget.pageNumber, _messageText.text);
      _messageText.clear();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startRecording() async {
    if (!widget.canEdit || _recordingFile != null || _saving) return;
    if (!AndroidVoiceAudioService.isAvailable && widget.audioService == null) {
      _showError(AppLocalizations.of(context).tr('voiceUnsupported'));
      return;
    }
    try {
      final id = 'voice_${const Uuid().v4()}';
      final file = await widget.sync.voiceStore.fileFor(widget.sync.sessionId, id);
      if (!await _audio.start(file.path)) {
        _showError(AppLocalizations.of(context).tr('micPermissionDenied'));
        return;
      }
      if (!mounted) {
        await _audio.cancel();
        return;
      }
      setState(() {
        _recordingId = id;
        _recordingFile = file;
        _stoppedDurationMs = null;
        _recordingSeconds = 0;
      });
      _recordingTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
      _recordingLimit = Timer(const Duration(seconds: 60), () {
        unawaited(_stopAndSend());
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _cancelRecording() async {
    _recordingLimit?.cancel();
    _recordingTick?.cancel();
    final file = _recordingFile;
    setState(() {
      _recordingFile = null;
      _recordingId = null;
      _stoppedDurationMs = null;
      _recordingSeconds = 0;
    });
    try {
      await _audio.cancel();
      if (file != null && await file.exists()) await file.delete();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _stopAndSend() async {
    if (_recordingFile == null || _saving) return;
    _recordingLimit?.cancel();
    _recordingTick?.cancel();
    final file = _recordingFile!;
    final id = _recordingId!;
    setState(() => _saving = true);
    try {
      final durationMs = _stoppedDurationMs ?? await _audio.stop();
      _stoppedDurationMs = durationMs;
      await widget.sync.sendVoice(widget.pageNumber, file, durationMs,
          messageId: id);
      if (mounted) setState(() {
        _recordingFile = null;
        _recordingId = null;
        _stoppedDurationMs = null;
        _recordingSeconds = 0;
      });
    } catch (error) {
      // Recording is still a local file if sharing fails. Never claim it was
      // sent; the user can cancel and retry a new recording.
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePlayback(SessionDiscussion message) async {
    try {
      if (_playingId == message.id) {
        await _audio.stopPlayback();
        if (mounted) setState(() => _playingId = null);
        return;
      }
      await _audio.stopPlayback();
      if (mounted) setState(() => _playingId = message.id);
      await _audio.play(message.voicePath!);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted && _playingId == message.id) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 38, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${l10n.tr('notesDiscussion')} — '
                  '${l10n.pageOf(widget.pageNumber, widget.sync.totalPages)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            TabBar(tabs: [
              Tab(text: l10n.tr('notesTab')),
              Tab(text: l10n.tr('discussionTab')),
            ]),
            Expanded(child: TabBarView(children: [
              _notesTab(l10n),
              _discussionTab(l10n),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _notesTab(AppLocalizations l10n) {
    return Column(children: [
      Expanded(child: StreamBuilder<List<SessionAnnotation>>(
        stream: widget.sync.repository.watchAnnotations(
          widget.sync.sessionId, widget.pageNumber, widget.sync.deviceId,
          kind: 'note'),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? [];
          return Scrollbar(
            controller: _notesScroll, thumbVisibility: true,
            child: ListView.builder(
              key: const Key('page_notes_list'), controller: _notesScroll,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(child: ListTile(
                  title: Text(note.content),
                  subtitle: Text('${note.authorName} · '
                      '${note.visibility == 'personal' ? l10n.tr('personalNote') : l10n.tr('sharedNote')}'
                      '${note.isPinned ? ' · 📌 ${l10n.tr('pinnedNote')}' : ''}'),
                  trailing: note.authorId == widget.sync.deviceId && widget.canEdit
                      ? IconButton(
                          key: Key('pin_note_${note.id}'),
                          icon: Icon(note.isPinned
                              ? Icons.push_pin : Icons.push_pin_outlined),
                          tooltip: note.isPinned ? l10n.tr('unpinNote') : l10n.tr('pinNote'),
                          onPressed: () async {
                            try {
                              await widget.sync.setPinned(note, !note.isPinned);
                            } catch (error) { _showError(error); }
                          },
                        ) : null,
                ));
              },
            ),
          );
        },
      )),
      StreamBuilder<List<SessionAnnotation>>(
        stream: widget.sync.repository.watchAnnotations(widget.sync.sessionId,
          widget.pageNumber, widget.sync.deviceId, kind: 'highlight'),
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('${l10n.tr('highlightPage')}: ${snapshot.data?.length ?? 0}',
              style: const TextStyle(fontSize: 12)),
        ),
      ),
      if (widget.canEdit) Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(children: [
          if (widget.isGroup) SwitchListTile(
            title: Text(_shared ? l10n.tr('sharedNote') : l10n.tr('personalNote')),
            value: _shared, onChanged: (v) => setState(() => _shared = v),
            dense: true, contentPadding: EdgeInsets.zero,
          ),
          Row(children: [
            Expanded(child: TextField(
              key: const Key('new_page_note'), controller: _noteText,
              maxLines: 2, maxLength: 2000,
              decoration: InputDecoration(hintText: l10n.tr('noteHint'),
                  border: const OutlineInputBorder()),
            )),
            IconButton(key: const Key('save_page_note'),
              onPressed: _saving ? null : _saveNote,
              tooltip: l10n.tr('saveNote'), icon: const Icon(Icons.save_outlined)),
          ]),
        ]),
      ),
    ]);
  }

  Widget _discussionTab(AppLocalizations l10n) {
    return Column(children: [
      Expanded(child: StreamBuilder<List<SessionDiscussion>>(
        stream: widget.sync.repository.watchDiscussion(
            widget.sync.sessionId, widget.pageNumber),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? [];
          return Scrollbar(
            controller: _messagesScroll, thumbVisibility: true,
            child: ListView.builder(
              key: const Key('page_discussion_list'), controller: _messagesScroll,
              padding: const EdgeInsets.all(12), itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Card(child: ListTile(
                  title: message.kind == 'voice'
                    ? Row(children: [
                        Expanded(child: Text('${l10n.tr('voiceMessage')} · '
                            '${((message.durationMs ?? 0) / 1000).toStringAsFixed(1)}s')),
                        IconButton(
                          key: Key('play_voice_${message.id}'),
                          icon: Icon(_playingId == message.id
                              ? Icons.stop : Icons.play_arrow),
                          tooltip: _playingId == message.id
                              ? l10n.tr('stopPlayback') : l10n.tr('playRecording'),
                          onPressed: message.voicePath == null
                              ? null : () => _togglePlayback(message),
                        ),
                      ])
                    : Text(message.content),
                  subtitle: Text(message.authorName),
                ));
              },
            ),
          );
        },
      )),
      if (widget.canEdit) Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: ['😀', '👍', '❤️', '😂', '👏'].map((emoji) =>
              TextButton(onPressed: () {
                _messageText.text += emoji;
                _messageText.selection = TextSelection.collapsed(
                    offset: _messageText.text.length);
              }, child: Text(emoji))).toList()),
          ),
          Row(children: [
            Expanded(child: TextField(
              key: const Key('new_page_message'), controller: _messageText,
              maxLines: 2, maxLength: 2000,
              decoration: InputDecoration(hintText: l10n.tr('messageHint'),
                  border: const OutlineInputBorder()),
            )),
            IconButton(key: const Key('send_page_message'),
              onPressed: _saving ? null : _sendText,
              tooltip: l10n.tr('sendMessage'), icon: const Icon(Icons.send)),
          ]),
          if (AndroidVoiceAudioService.isAvailable || widget.audioService != null)
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
              if (_recordingFile == null)
                TextButton.icon(key: const Key('start_voice_recording'),
                  onPressed: _saving ? null : _startRecording,
                  icon: const Icon(Icons.mic), label: Text(l10n.tr('startRecording')))
              else ...[
                TextButton.icon(key: const Key('stop_voice_recording'),
                  onPressed: _saving ? null : _stopAndSend,
                  icon: const Icon(Icons.stop), label: Text(l10n.tr('stopRecording'))),
                TextButton(key: const Key('cancel_voice_recording'),
                  onPressed: _saving ? null : _cancelRecording,
                  child: Text(l10n.tr('cancelRecording'))),
                Text('${_recordingSeconds}s',
                    key: const Key('recording_elapsed_time')),
              ],
            ]),
        ]),
      ),
    ]);
  }
}
