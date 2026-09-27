import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/audio_message_repository.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/audio_messages/presentation/audio_clip_player.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_controller.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_panel.dart';

import 'fake_local_audio_service.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late SessionVoiceStore files;
  late AudioMessageRepository audio;
  late MessageRepository text;
  late TextMessagesController controller;
  late FakeLocalAudioService service;

  /// Real filesystem/SQLite work runs outside the widget test's fake clock.
  /// Wait for the requested state, not an arbitrary sleep or pumpAndSettle
  /// (the recording/playback timers deliberately remain active).
  Future<void> waitForIO(WidgetTester tester, {
    Finder? until,
    bool Function()? widgetReady,
    Future<bool> Function()? completed,
    String step = 'local audio I/O',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < timeout) {
      // The delay and check run in the real-clock zone; a .timeout outside
      // runAsync would be a fake timer and could never fire while awaiting I/O.
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pump();
      final error = tester.takeException();
      if (error != null) fail('Flutter error while waiting for $step: $error');
      if (until != null && until.evaluate().isEmpty) continue;
      if (widgetReady != null && !widgetReady()) continue;
      final check = completed;
      if (check != null) {
        final remaining = timeout - elapsed.elapsed;
        if (remaining <= Duration.zero) break;
        final ready = await tester.runAsync(() => check().timeout(
          remaining,
          onTimeout: () => throw TimeoutException(
              'Completion check stalled: $step', timeout),
        ));
        if (ready != true) continue;
      }
      return;
    }
    final snackbars = find.byType(SnackBar).evaluate();
    final snackbar = snackbars.isEmpty ? null :
        (snackbars.first.widget as SnackBar).content;
    final reason = snackbar is Text ? snackbar.data : snackbar?.toString();
    fail('Timed out after ${timeout.inSeconds}s waiting for $step. '
        'Recording path: ${service.recordingPath}; '
        'Recording UI: ${find.byKey(const Key('pause_audio_recording')).evaluate().isNotEmpty}; '
        'Paused UI: ${find.byKey(const Key('resume_audio_recording')).evaluate().isNotEmpty}; '
        'Preview UI: ${find.byKey(const Key('audio_draft_preview')).evaluate().isNotEmpty}; '
        'Panel error UI: ${find.byKey(const Key('text_message_error')).evaluate().isNotEmpty}; '
        'Snackbar error: ${reason ?? 'none'}.');
  }

  Future<void> waitForPanelLoaded(WidgetTester tester, String step) =>
      waitForIO(tester,
        widgetReady: () {
          final panel = find.byKey(const Key('text_messages_panel'));
          if (panel.evaluate().isEmpty) return false;
          final emptyLabel = AppLocalizations.of(tester.element(panel))
              .tr('noPageMessages');
          return find.byKey(const Key('text_message_list'))
                  .evaluate().isNotEmpty ||
              find.text(emptyLabel).evaluate().isNotEmpty;
        },
        step: step);

  Future<void> waitForEnabledIcon(WidgetTester tester, String key,
      String step, {Future<bool> Function()? completed}) =>
      waitForIO(tester,
        until: find.byKey(Key(key)),
        widgetReady: () => tester.widget<IconButton>(find.byKey(Key(key)))
            .onPressed != null,
        completed: completed,
        step: step);

  Future<void> waitForPreview(WidgetTester tester, String step) =>
      waitForIO(tester,
        until: find.byKey(const Key('audio_draft_preview')),
        widgetReady: () => tester.widget<TextButton>(
            find.byKey(const Key('send_audio_message'))).onPressed != null,
        step: step);

  Widget app(int page) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SizedBox(height: 440, child: TextMessagesPanel(
      sessionId: 'solo_audio-ui', pageNumber: page,
      senderId: 'owner', senderName: 'أحمد', canSend: true,
      controller: controller, audioRepository: audio,
      audioService: service, voiceStore: files,
    ))),
  );

  Future<void> recordToPreview(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('send_text_message_button')));
    await waitForEnabledIcon(tester, 'pause_audio_recording',
      'Idle → Recording (Pause enabled)');
    expect(find.byKey(const Key('pause_audio_recording')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop_audio_recording')));
    await waitForPreview(tester, 'Recording → Preview after Stop');
    expect(find.byKey(const Key('audio_draft_preview')), findsOneWidget);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase7_audio_panel_');
    db = AppDatabase.memory();
    files = SessionVoiceStore(root);
    audio = AudioMessageRepositoryImpl(db, files);
    text = MessageRepositoryImpl(db);
    service = FakeLocalAudioService();
    await BookRepositoryImpl(db).createBook(id: 'book-audio-ui',
      title: 'Book', author: 'Local', filePath: '/tmp/audio-ui.pdf',
      fileSize: 100, pageCount: 20, sha256Hash: 'phase7-audio-ui');
    await SessionRepositoryImpl(db).createSession(id: 'solo_audio-ui',
      title: 'Solo', hostDeviceId: 'owner', bookId: 'book-audio-ui',
      status: 'active');
    controller = TextMessagesController(repository: text,
      sessionId: 'solo_audio-ui', senderId: 'owner', senderName: 'أحمد');
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  testWidgets('one text/mic composer, pause/resume same file, preview then Send',
      (tester) async {
    await tester.pumpWidget(app(8));
    await waitForPanelLoaded(tester, 'page 8 message streams loaded');
    final send = find.byKey(const Key('send_text_message_button'));
    final panelBottom = tester.getBottomLeft(
        find.byKey(const Key('text_messages_panel'))).dy;
    final composer = find.byKey(const Key('discussion_composer'));
    expect(tester.getTopLeft(composer).dy, greaterThan(tester.getBottomLeft(
        find.byKey(const Key('text_messages_header'))).dy));
    expect(tester.getBottomLeft(composer).dy, lessThanOrEqualTo(panelBottom));
    expect(tester.getBottomLeft(send).dy, lessThanOrEqualTo(panelBottom));
    expect(tester.takeException(), isNull);
    expect((tester.widget<IconButton>(send).icon as Icon).icon,
      Icons.mic_none);
    expect(find.byKey(const Key('pause_audio_recording')), findsNothing);
    expect(find.byKey(const Key('resume_audio_recording')), findsNothing);
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.enterText(find.byKey(const Key('text_message_input')),
      'السلام عليكم');
    await tester.pump(); // TextEditingController schedules the send-icon rebuild.
    expect((tester.widget<IconButton>(send).icon as Icon).icon, Icons.send);
    await tester.tap(send);
    await waitForIO(tester,
      until: find.descendant(
        of: find.byKey(const Key('text_message_list')),
        matching: find.text('السلام عليكم')),
      widgetReady: () {
        final input = tester.widget<TextField>(
            find.byKey(const Key('text_message_input')));
        final button = tester.widget<IconButton>(send);
        return input.controller!.text.isEmpty &&
            (button.icon as Icon).icon == Icons.mic_none &&
            button.onPressed != null;
      },
      step: 'text message committed and composer returned to microphone');
    expect((tester.widget<IconButton>(send).icon as Icon).icon,
      Icons.mic_none);
    expect((await text.getPageText('solo_audio-ui', 8)).single.text,
      'السلام عليكم');
    expect(tester.widget<TextField>(find.byKey(const Key('text_message_input')))
        .controller!.text, isEmpty);

    await tester.tap(send);
    await waitForEnabledIcon(tester, 'pause_audio_recording',
      'Idle → Recording after the microphone tap');
    final sameFile = service.recordingPath!;
    expect(find.byKey(const Key('audio_recording_timer')), findsOneWidget);
    expect(find.byKey(const Key('resume_audio_recording')), findsNothing);
    expect(find.byKey(const Key('cancel_audio_recording')), findsOneWidget);
    expect(tester.getBottomLeft(find.byKey(const Key('stop_audio_recording'))).dy,
      lessThanOrEqualTo(panelBottom));
    expect(tester.takeException(), isNull);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
    await tester.tap(find.byKey(const Key('pause_audio_recording')));
    await waitForEnabledIcon(tester, 'resume_audio_recording',
      'Recording → Paused (Resume enabled)');
    expect(service.recordingPaused, isTrue);
    expect(find.byKey(const Key('pause_audio_recording')), findsNothing);
    expect(find.byKey(const Key('resume_audio_recording')), findsOneWidget);
    expect(find.byKey(const Key('stop_audio_recording')), findsOneWidget);
    expect(find.byKey(const Key('cancel_audio_recording')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume_audio_recording')));
    await waitForEnabledIcon(tester, 'pause_audio_recording',
      'Paused → Recording on the same file',
      completed: () async => service.resumeCalls == 1 &&
          await File(sameFile).length() == 320);
    expect(service.recordingPath, sameFile);
    expect(service.resumeCalls, 1);
    expect(find.byKey(const Key('resume_audio_recording')), findsNothing);
    expect(await File(sameFile).length(), 320);
    await tester.tap(find.byKey(const Key('stop_audio_recording')));
    await waitForPreview(tester, 'Recording → Preview after Stop');
    expect(find.byKey(const Key('audio_draft_preview')), findsOneWidget);
    expect(find.byKey(const Key('pause_audio_recording')), findsNothing);
    expect(find.byKey(const Key('resume_audio_recording')), findsNothing);
    expect(find.byKey(const Key('cancel_audio_recording')), findsOneWidget);
    expect(tester.getBottomLeft(find.byKey(const Key('send_audio_message'))).dy,
      lessThanOrEqualTo(panelBottom));
    expect(tester.takeException(), isNull);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
    expect(await File(sameFile).exists(), isTrue);
    expect(find.text('00:02'), findsWidgets);

    await tester.tap(find.byKey(Key('audio_play_${_draftId(sameFile)}')));
    await tester.pump();
    expect(service.playbackPath, sameFile);
    await tester.tap(find.byKey(Key('audio_play_${_draftId(sameFile)}')));
    await tester.pump();
    expect(service.playing, isFalse);
    final pausedPosition = service.positionMs;
    await tester.tap(find.byKey(Key('audio_play_${_draftId(sameFile)}')));
    await tester.pump();
    expect(service.positionMs, greaterThanOrEqualTo(pausedPosition));
    await tester.tap(find.byKey(Key('audio_stop_${_draftId(sameFile)}')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('send_audio_message')));
    await waitForIO(tester,
      until: find.byKey(const Key('send_text_message_button')),
      step: 'Preview → committed audio message');
    final committed = (await audio.getPage('solo_audio-ui', 8)).single;
    await waitForIO(tester,
      until: find.byKey(Key('audio_message_${committed.id}')),
      step: 'committed audio tile displayed beside the text message');
    final tile = find.byKey(Key('audio_message_${committed.id}'));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('أحمد')),
      findsOneWidget);
    expect(find.descendant(of: tile,
      matching: find.byKey(Key('audio_play_${committed.id}'))),
      findsOneWidget);
    expect(tester.widget<Text>(find.byKey(Key('audio_duration_${committed.id}')))
        .data, '00:02');
    final at = committed.createdAt.toLocal();
    final timeLabel = '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    expect(find.descendant(of: tile, matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == timeLabel &&
          widget.style?.fontSize == 11)), findsOneWidget);
    expect(find.text('السلام عليكم'), findsOneWidget);
    final textRow = (await text.getPageText('solo_audio-ui', 8)).single;
    expect(committed.localOrder!, greaterThan(textRow.localOrder!));
    expect(tester.getTopLeft(find.byKey(Key('audio_message_${committed.id}'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(
          Key('text_message_${textRow.id}'))).dy));
    expect(await File(sameFile).exists(), isFalse);
    expect(await File(committed.audioPath).exists(), isTrue);
    expect(committed.senderDisplayName, 'أحمد');
    expect(committed.durationMs, 2500);
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.pumpWidget(app(9));
    await waitForPanelLoaded(tester, 'page 9 message streams loaded');
    expect(find.byKey(Key('audio_message_${committed.id}')), findsNothing);
    expect(find.text('السلام عليكم'), findsNothing);
    await tester.pumpWidget(app(8));
    await waitForPanelLoaded(tester, 'page 8 message streams loaded');
    expect(find.byKey(Key('audio_message_${committed.id}')), findsOneWidget);
  });

  testWidgets('discard preview and page navigation cancel draft, no DB row',
      (tester) async {
    await tester.pumpWidget(app(8));
    await waitForPanelLoaded(tester, 'page 8 message streams loaded');
    await recordToPreview(tester);
    final firstDraft = service.recordingPath!;
    await tester.tap(find.byKey(const Key('cancel_audio_recording')));
    await waitForIO(tester,
      until: find.byKey(const Key('send_text_message_button')),
      completed: () async => !await File(firstDraft).exists(),
      step: 'Preview → Idle; draft removed on Cancel');
    expect(await File(firstDraft).exists(), isFalse);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);

    await tester.tap(find.byKey(const Key('send_text_message_button')));
    await waitForEnabledIcon(tester, 'pause_audio_recording',
      'second recording started before page change');
    final pageEightDraft = service.recordingPath!;
    await tester.pumpWidget(app(9));
    await waitForIO(tester,
      until: find.byKey(const Key('send_text_message_button')),
      completed: () async => !await File(pageEightDraft).exists(),
      step: 'page 8 draft removed on navigation to page 9');
    expect(find.byKey(const Key('audio_recording_timer')), findsNothing);
    expect(await File(pageEightDraft).exists(), isFalse);
    expect(service.cancelCalls, greaterThan(0));
    expect(await audio.getPage('solo_audio-ui', 9), isEmpty);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
  });

  testWidgets('leaving Reader while previewing discards uncommitted file',
      (tester) async {
    await tester.pumpWidget(app(8));
    await waitForPanelLoaded(tester, 'page 8 message streams loaded');
    await recordToPreview(tester);
    final pending = service.recordingPath!;
    expect(await File(pending).exists(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await waitForIO(tester,
      completed: () async => !await File(pending).exists(),
      step: 'Reader disposal removes uncommitted preview');
    expect(await File(pending).exists(), isFalse);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
  });

  testWidgets('replace/delete buttons only on own audio, text stays intact',
      (tester) async {
    Future<void> seedVoice(String id, String sender) async {
      final file = await files.fileFor('solo_audio-ui', 'draft_$id');
      await file.writeAsBytes(List<int>.filled(256, 20));
      await audio.send(id: id, sessionId: 'solo_audio-ui', pageNumber: 8,
        senderId: sender, senderDisplayName: sender, draft: file,
        durationMs: 2000);
    }
    await seedVoice('audio_owned', 'owner');
    await seedVoice('audio_other', 'other');
    await text.createText(id: 'text_keep', sessionId: 'solo_audio-ui',
      pageNumber: 8, senderId: 'owner', senderName: 'أحمد', text: 'Retain text');
    final oldPath = (await audio.getPage('solo_audio-ui', 8))
      .firstWhere((voice) => voice.id == 'audio_owned').audioPath;
    await tester.pumpWidget(app(8));
    await waitForPanelLoaded(tester, 'page 8 message streams loaded');
    expect(find.byKey(const Key('audio_message_audio_other')), findsOneWidget);
    expect(find.byKey(const Key('replace_audio_audio_other')), findsNothing);
    expect(find.byKey(const Key('delete_audio_audio_other')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('replace_audio_audio_owned')));
    await tester.tap(find.byKey(const Key('replace_audio_audio_owned')));
    await waitForEnabledIcon(tester, 'pause_audio_recording',
      'own audio replacement → Recording (Pause enabled)');
    await tester.tap(find.byKey(const Key('stop_audio_recording')));
    await waitForPreview(tester, 'replacement Recording → Preview');
    expect((await audio.getPage('solo_audio-ui', 8)).length, 2);
    await tester.tap(find.byKey(const Key('send_audio_message')));
    await waitForIO(tester,
      until: find.byKey(const Key('send_text_message_button')),
      completed: () async {
        final rows = await audio.getPage('solo_audio-ui', 8);
        return rows.length == 2 &&
            rows.every((row) => row.id != 'audio_owned');
      },
      step: 'replacement committed, original audio removed');
    final updated = await audio.getPage('solo_audio-ui', 8);
    expect(updated.length, 2);
    expect(updated.map((voice) => voice.id), isNot(contains('audio_owned')));
    final newOwn = updated.firstWhere((voice) => voice.senderId == 'owner');
    expect(await File(oldPath).exists(), isFalse);
    expect(await File(newOwn.audioPath).exists(), isTrue);
    expect((await text.getPageText('solo_audio-ui', 8)).single.text,
      'Retain text');
    await waitForIO(tester,
      until: find.byKey(Key('delete_audio_${newOwn.id}')),
      step: 'replacement tile visible before Delete');
    await tester.ensureVisible(find.byKey(Key('delete_audio_${newOwn.id}')));
    await tester.tap(find.byKey(Key('delete_audio_${newOwn.id}')));
    await waitForIO(tester,
      widgetReady: () => find.byKey(Key('audio_message_${newOwn.id}'))
          .evaluate().isEmpty,
      completed: () async => !await File(newOwn.audioPath).exists() &&
          (await audio.getPage('solo_audio-ui', 8)).length == 1,
      step: 'own audio deleted from UI, SQLite, and local files');
    expect(await File(newOwn.audioPath).exists(), isFalse);
    expect((await audio.getPage('solo_audio-ui', 8)).single.id,
      'audio_other');
    expect((await text.getPageText('solo_audio-ui', 8)).single.text,
      'Retain text');
  });

  testWidgets('player Pause/Resume retains position, Stop resets it',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AudioClipPlayer(
      id: 'clip', path: '/fake/audio.m4a', durationMs: 2500,
      audio: service,
    ))));
    final play = find.byKey(const Key('audio_play_clip'));
    await tester.tap(play);
    await tester.pump();
    expect(service.playing, isTrue);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('audio_progress_clip')));
    expect(progress.value!, greaterThan(0));
    await tester.tap(play);
    await tester.pump();
    final paused = service.positionMs;
    expect(service.playing, isFalse);
    await tester.tap(play);
    await tester.pump();
    expect(service.playing, isTrue);
    expect(service.positionMs, greaterThanOrEqualTo(paused));
    await tester.tap(find.byKey(const Key('audio_stop_clip')));
    await tester.pump();
    expect(service.playbackPath, isNull);
    expect(tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('audio_progress_clip'))).value, 0);
  });
}

String _draftId(String path) => path.split(Platform.pathSeparator).last
    .replaceFirst('.m4a', '').replaceFirst('draft_', '');
