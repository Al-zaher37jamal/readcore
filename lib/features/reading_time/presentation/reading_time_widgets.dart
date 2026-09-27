import 'package:flutter/material.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/core/theme/app_theme.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/features/reading_time/domain/session_reading_timer.dart';
import 'session_reading_timer_controller.dart';

const readerSessionInfoBarHeight = 43.0;

String readingTimeLabel(AppLocalizations l10n,
    SessionReadingTimerController controller) {
  final timer = controller.value;
  switch (controller.status) {
    case ReadingTimerStatus.notConfigured:
      return l10n.tr('readingTimerNotConfigured');
    case ReadingTimerStatus.configured:
      return l10n.tr('readingTimerMinutes', params: {
        'count': '${timer!.durationMinutes}',
      });
    case ReadingTimerStatus.running:
      final remaining = controller.remainingSeconds;
      return '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
    case ReadingTimerStatus.finished:
      return l10n.tr('readingTimerFinished');
  }
}

/// Only this badge listens to the countdown. A tick cannot rebuild the Reader
/// or recreate its pdfx view, page controls or discussion stream.
class ReadingTimeBadge extends StatelessWidget {
  final SessionReadingTimerController? controller;
  const ReadingTimeBadge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timer = controller;
    if (timer == null) {
      return _badge(l10n.tr('readingTimerError'),
          AppTheme.softWarning, AppTheme.textSecondaryColor);
    }
    return AnimatedBuilder(animation: timer, builder: (context, _) {
      final status = timer.status;
      final totalSeconds = (timer.value?.durationMinutes ?? 0) * 60;
      final nearEndAt = totalSeconds < 1500 ? totalSeconds ~/ 5 : 300;
      final nearEnd = status == ReadingTimerStatus.running &&
          timer.remainingSeconds <= nearEndAt;
      final background = status == ReadingTimerStatus.notConfigured
          ? AppTheme.softSky
          : status == ReadingTimerStatus.finished ? AppTheme.softSuccess
          : nearEnd ? AppTheme.softWarning : AppTheme.softBlue;
      final foreground = status == ReadingTimerStatus.notConfigured
          ? AppTheme.textSecondaryColor
          : status == ReadingTimerStatus.finished
              ? const Color(0xFF216A4C)
              : nearEnd ? const Color(0xFF8A651A) : AppTheme.primaryColor;
      return _badge(readingTimeLabel(l10n, timer), background, foreground,
          numeric: status == ReadingTimerStatus.running);
    });
  }

  Widget _badge(String label, Color background, Color foreground,
      {bool numeric = false}) =>
      Container(
        key: const Key('reading_time_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: background,
          borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timer_outlined, size: 17, color: foreground),
          const SizedBox(width: 5),
          Flexible(child: Text(label, key: const Key('reading_time_status'),
            textDirection: numeric ? TextDirection.ltr : null,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600,
                fontSize: 12))),
        ]),
      );
}

class ReaderSessionInfoBar extends StatelessWidget {
  final SessionReadingTimerController? timer;
  final Stream<List<SessionMember>>? members;
  final String hostDeviceId;
  final bool isGroup;

  const ReaderSessionInfoBar({super.key, required this.timer,
      required this.members, required this.hostDeviceId,
      required this.isGroup});

  @override
  Widget build(BuildContext context) => Container(
    height: readerSessionInfoBarHeight,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: const BoxDecoration(color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (isGroup) ...[
        StreamBuilder<List<SessionMember>>(
          stream: members,
          builder: (context, snapshot) {
            final active = snapshot.data?.where((member) =>
                member.status == 'active').map((member) => member.deviceId)
                .toSet() ?? <String>{};
            if (hostDeviceId.isNotEmpty) active.add(hostDeviceId);
            return Semantics(
              label: '${AppLocalizations.of(context).participants}: ${active.length}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.softSky,
                  borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline, size: 17,
                      color: AppTheme.textSecondaryColor),
                  const SizedBox(width: 5),
                  Text('${active.length}', key: const Key('reader_participant_count'),
                    style: const TextStyle(color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
      ],
      Flexible(child: ReadingTimeBadge(controller: timer)),
    ]),
  );
}

/// A small expandable region after page controls. Expanding/ticking it does
/// not require PdfReaderScreen.setState; future tools can become siblings.
class ReaderToolsSection extends StatefulWidget {
  final SessionReadingTimerController? timer;
  final bool canEditSession;
  final bool elapsedEnabled;
  final ValueListenable<int> elapsedSeconds;
  final bool statsEnabled;
  final ValueChanged<String> onOptionSelected;

  const ReaderToolsSection({super.key, required this.timer,
    required this.canEditSession, required this.elapsedEnabled,
    required this.elapsedSeconds, required this.statsEnabled,
    required this.onOptionSelected});

  @override
  State<ReaderToolsSection> createState() => _ReaderToolsSectionState();
}

class _ReaderToolsSectionState extends State<ReaderToolsSection> {
  bool _expanded = false;

  Future<void> _showSettings() async {
    final controller = widget.timer;
    if (controller == null || !controller.isLeader ||
        !widget.canEditSession || controller.status == ReadingTimerStatus.running) {
      return;
    }
    await showModalBottomSheet<void>(context: context,
      isScrollControlled: true, backgroundColor: AppTheme.surfaceColor,
      builder: (context) => ReadingTimeSettingsSheet(controller: controller));
  }

  Future<void> _start() async {
    try {
      await widget.timer!.start();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${AppLocalizations.of(context).tr('readingTimerError')}: $error'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('reader_tools_section'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: AppTheme.softSky,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          key: const Key('reader_tools_toggle'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.handyman_outlined, size: 20,
                  color: AppTheme.textPrimaryColor),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.tr('readerTools'),
                style: const TextStyle(color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600))),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppTheme.textSecondaryColor),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: AppTheme.borderColor),
          if (widget.timer == null)
            ListTile(title: Text(l10n.tr('readingTimerError')))
          else AnimatedBuilder(animation: widget.timer!, builder: (context, _) {
            final controller = widget.timer!;
            final canSet = controller.isLeader && widget.canEditSession &&
                controller.status != ReadingTimerStatus.running;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                key: const Key('reading_time_settings_entry'),
                leading: const Icon(Icons.timer_outlined,
                    color: AppTheme.primaryColor),
                title: Text(l10n.tr('readingTimerTitle')),
                subtitle: Text(readingTimeLabel(l10n, controller),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: canSet
                    ? const Icon(Icons.edit_outlined,
                        color: AppTheme.primaryColor) : null,
                onTap: canSet ? _showSettings : null,
              ),
              if (canSet && controller.status == ReadingTimerStatus.configured)
                Padding(padding: const EdgeInsetsDirectional.only(
                    start: 14, end: 14, bottom: 8),
                  child: Align(alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('start_reading_timer'),
                      onPressed: controller.busy ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.tr('readingTimerStart')),
                    ),
                  ),
                ),
            ]);
          }),
          if (widget.elapsedEnabled)
            Padding(padding: const EdgeInsetsDirectional.only(
                start: 16, end: 16, bottom: 4),
              child: ValueListenableBuilder<int>(
                valueListenable: widget.elapsedSeconds,
                builder: (context, seconds, _) => Text(
                  '${l10n.enableTimerLabel}: '
                  '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
                  '${(seconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12,
                      color: AppTheme.textSecondaryColor)),
              ),
            ),
          if (widget.timer?.isLeader == true)
            Padding(padding: const EdgeInsetsDirectional.only(
                start: 14, end: 8, bottom: 4),
              child: Row(children: [
                Expanded(child: Text(l10n.enableStatsLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                        color: AppTheme.textSecondaryColor))),
                PopupMenuButton<String>(
                  key: const Key('reader_timer_stats_menu'),
                  icon: const Icon(Icons.more_horiz),
                  tooltip: l10n.enableStatsLabel,
                  enabled: widget.canEditSession,
                  onSelected: widget.onOptionSelected,
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(value: 'timer',
                      checked: widget.elapsedEnabled,
                      child: Text(l10n.enableTimerLabel)),
                    CheckedPopupMenuItem(value: 'stats',
                      checked: widget.statsEnabled,
                      child: Text(l10n.enableStatsLabel)),
                  ],
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

class ReadingTimeSettingsSheet extends StatefulWidget {
  final SessionReadingTimerController controller;
  const ReadingTimeSettingsSheet({super.key, required this.controller});

  @override
  State<ReadingTimeSettingsSheet> createState() =>
      _ReadingTimeSettingsSheetState();
}

class _ReadingTimeSettingsSheetState extends State<ReadingTimeSettingsSheet> {
  static const _choices = [15, 30, 45, 60, 90];
  final TextEditingController _custom = TextEditingController();
  int? _selected;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final minutes = widget.controller.value?.durationMinutes;
    if (_choices.contains(minutes)) {
      _selected = minutes;
    } else if (minutes != null) {
      _selected = 0;
      _custom.text = '$minutes';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final minutes = _selected == 0
        ? int.tryParse(_custom.text.trim()) : _selected;
    if (minutes == null || minutes < 1 || minutes > 1440) {
      setState(() => _error = l10n.tr('readingTimerInvalid'));
      return;
    }
    setState(() { _error = null; _saving = true; });
    try {
      await widget.controller.configure(minutes);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error =
          '${l10n.tr('readingTimerError')}: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text(l10n.tr('readingTimerTitle'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor))),
              const SizedBox(height: 14),
              Text(l10n.tr('readingTimerChoose'),
                  style: const TextStyle(color: AppTheme.textSecondaryColor)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8,
                children: _choices.map((minutes) => ChoiceChip(
                  key: Key('reading_time_option_$minutes'),
                  label: Text('$minutes'),
                  selected: _selected == minutes,
                  selectedColor: AppTheme.softBlue,
                  onSelected: (_) => setState(() {
                    _selected = minutes;
                    _error = null;
                  }),
                )).toList()),
              const SizedBox(height: 8),
              ChoiceChip(
                key: const Key('reading_time_custom_option'),
                label: Text(l10n.tr('readingTimerCustom')),
                selected: _selected == 0,
                selectedColor: AppTheme.softBlue,
                onSelected: (_) => setState(() {
                  _selected = 0;
                  _error = null;
                }),
              ),
              if (_selected == 0) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('reading_time_custom_minutes'),
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.tr('readingTimerCustomHint')),
                ),
              ],
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, key: const Key('reading_time_validation_error'),
                  style: const TextStyle(color: Color(0xFF9A6700))),
              ),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel)),
                const Spacer(),
                FilledButton(
                  key: const Key('reading_time_save'),
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.tr('readingTimerSave')),
                ),
              ]),
            ],
          ),
        ),
      ),
    ));
  }
}
