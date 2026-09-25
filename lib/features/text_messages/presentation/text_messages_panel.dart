import 'dart:async';

import 'package:flutter/material.dart';
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

  const TextMessagesPanel({super.key, required this.sessionId,
    required this.pageNumber, required this.senderId, required this.senderName,
    required this.canSend, this.controller});

  @override
  State<TextMessagesPanel> createState() => _TextMessagesPanelState();
}

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

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraftChanged);
    _bindController();
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _retry() {
    setState(() {
      _streamRevision++;
      _bindController();
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

  @override
  void didUpdateWidget(covariant TextMessagesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId ||
        widget.senderId != oldWidget.senderId ||
        widget.senderName != oldWidget.senderName ||
        widget.controller != oldWidget.controller) {
      _pageDrafts.clear();
      _draft.removeListener(_onDraftChanged);
      _draft.clear();
      _draft.addListener(_onDraftChanged);
      _editingId = null;
      _bindController();
    } else if (widget.pageNumber != oldWidget.pageNumber) {
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
      _lastMessageId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
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
    if (controller == null || !widget.canSend || _busy ||
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
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData && !snapshot.hasError;
            final messages = snapshot.data ?? const <TextMessage>[];
            final lastId = messages.isEmpty ? null : messages.last.id;
            if (!snapshot.hasError && !loading && lastId != _lastMessageId) {
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
                  Flexible(flex: 2, child: Text(l10n.tr('textMessagesTitle'),
                    key: const Key('text_messages_header'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Text('${messages.length}', key: const Key('text_message_count'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Flexible(child: Text(l10n.tr('textMessagesLocal'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                ]),
              ),
              Expanded(child: snapshot.hasError
                ? SingleChildScrollView(key: const Key('text_message_error'),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.tr('textMessageError'), textAlign: TextAlign.center),
                      Text('${snapshot.error}', textAlign: TextAlign.center,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                      TextButton(
                        key: const Key('retry_text_messages'),
                        onPressed: _retry,
                        child: Text(l10n.tr('retryMessages')),
                      ),
                    ]))
                : loading
                  ? const Center(child: CircularProgressIndicator(
                      key: Key('text_message_loading')))
                  : messages.isEmpty
                    ? Center(child: Text(l10n.tr('noPageMessages'),
                        style: const TextStyle(color: Color(0xFF64748B))))
                    : ListView.builder(
                    key: const Key('text_message_list'),
                    controller: _scroll,
                    reverse: true, // index 0 (newest) starts at the bottom
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        _messageTile(messages[messages.length - 1 - index], l10n),
                  )),
            ]);
          },
        )),
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
              onPressed: widget.canSend && _controller != null
                  ? () => setState(() => _showEmoji = !_showEmoji) : null),
            Expanded(child: TextField(
              key: const Key('text_message_input'), controller: _draft,
              enabled: widget.canSend && _controller != null && !_busy,
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
                  ? l10n.tr('voicePlaceholder') : l10n.tr('sendMessage'),
              color: const Color(0xFF2563EB),
              // Placeholder only: no audio service or recording action here.
              onPressed: _controller != null && widget.canSend && !_busy &&
                  _draft.text.trim().isNotEmpty ? _send : null),
          ]),
        )),
      ]),
    );
  }
}
