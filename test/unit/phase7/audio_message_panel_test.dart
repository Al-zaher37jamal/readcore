import 'dart:io';

import 'package:flutter/material.dart';
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

  Future<void> waitForIO(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 80)));
    await tester.pump();
  }

  Widget app(int page) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [AppLocalizationsDelegate()],
    home: Scaffold(body: SizedBox(height: 440, child: TextMessagesPanel(
      sessionId: 'solo_audio-ui', pageNumber: page,
      senderId: 'owner', senderName: 'أحمد', canSend: true,
      controller: controller, audioRepository: audio,
      audioService: service, voiceStore: files,
    ))),
  );

  Future<void> recordToPreview(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('send_text_message_button')));
    await waitForIO(tester); // filesystem + fake microphone
    expect(find.byKey(const Key('pause_audio_recording')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop_audio_recording')));
    await waitForIO(tester);
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
    await waitForIO(tester);
    final send = find.byKey(const Key('send_text_message_button'));
    expect((tester.widget<IconButton>(send).icon as Icon).icon,
      Icons.mic_none);
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.enterText(find.byKey(const Key('text_message_input')),
      'السلام عليكم');
    expect((tester.widget<IconButton>(send).icon as Icon).icon, Icons.send);
    await tester.tap(send);
    await waitForIO(tester);
    expect((await text.getPageText('solo_audio-ui', 8)).single.text,
      'السلام عليكم');
    expect(tester.widget<TextField>(find.byKey(const Key('text_message_input')))
        .controller!.text, isEmpty);

    await tester.tap(send);
    await waitForIO(tester);
    final sameFile = service.recordingPath!;
    expect(find.byKey(const Key('audio_recording_timer')), findsOneWidget);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
    await tester.tap(find.byKey(const Key('pause_audio_recording')));
    await tester.pump();
    expect(service.recordingPaused, isTrue);
    expect(find.byKey(const Key('resume_audio_recording')), findsOneWidget);
    await tester.tap(find.byKey(const Key('resume_audio_recording')));
    await waitForIO(tester);
    expect(service.recordingPath, sameFile);
    expect(service.resumeCalls, 1);
    expect(await File(sameFile).length(), 320);
    await tester.tap(find.byKey(const Key('stop_audio_recording')));
    await waitForIO(tester);
    expect(find.byKey(const Key('audio_draft_preview')), findsOneWidget);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
    expect(await File(sameFile).exists(), isTrue);
    expect(find.text('00:02'), findsWidgets);

    await tester.tap(find.byKey(const Key('audio_play_${_draftId(sameFile)}')));
    await tester.pump();
    expect(service.playbackPath, sameFile);
    await tester.tap(find.byKey(const Key('audio_play_${_draftId(sameFile)}')));
    await tester.pump();
    expect(service.playing, isFalse);
    final pausedPosition = service.positionMs;
    await tester.tap(find.byKey(const Key('audio_play_${_draftId(sameFile)}')));
    await tester.pump();
    expect(service.positionMs, greaterThanOrEqualTo(pausedPosition));
    await tester.tap(find.byKey(const Key('audio_stop_${_draftId(sameFile)}')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('send_audio_message')));
    await waitForIO(tester);
    final committed = (await audio.getPage('solo_audio-ui', 8)).single;
    expect(find.byKey(Key('audio_message_${committed.id}')), findsOneWidget);
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
    await waitForIO(tester);
    expect(find.byKey(Key('audio_message_${committed.id}')), findsNothing);
    expect(find.text('السلام عليكم'), findsNothing);
    await tester.pumpWidget(app(8));
    await waitForIO(tester);
    expect(find.byKey(Key('audio_message_${committed.id}')), findsOneWidget);
  });

  testWidgets('discard preview and page navigation cancel draft, no DB row',
      (tester) async {
    await tester.pumpWidget(app(8));
    await waitForIO(tester);
    await recordToPreview(tester);
    final firstDraft = service.recordingPath!;
    await tester.tap(find.byKey(const Key('cancel_audio_recording')));
    await waitForIO(tester);
    expect(await File(firstDraft).exists(), isFalse);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);

    await tester.tap(find.byKey(const Key('send_text_message_button')));
    await waitForIO(tester);
    final pageEightDraft = service.recordingPath!;
    await tester.pumpWidget(app(9));
    await waitForIO(tester);
    expect(find.byKey(const Key('audio_recording_timer')), findsNothing);
    expect(await File(pageEightDraft).exists(), isFalse);
    expect(service.cancelCalls, greaterThan(0));
    expect(await audio.getPage('solo_audio-ui', 9), isEmpty);
    expect(await audio.getPage('solo_audio-ui', 8), isEmpty);
  });

  testWidgets('leaving Reader while previewing discards uncommitted file',
      (tester) async {
    await tester.pumpWidget(app(8));
    await waitForIO(tester);
    await recordToPreview(tester);
    final pending = service.recordingPath!;
    expect(await File(pending).exists(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await waitForIO(tester);
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
    await waitForIO(tester);
    expect(find.byKey(const Key('audio_message_audio_other')), findsOneWidget);
    expect(find.byKey(const Key('replace_audio_audio_other')), findsNothing);
    expect(find.byKey(const Key('delete_audio_audio_other')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('replace_audio_audio_owned')));
    await tester.tap(find.byKey(const Key('replace_audio_audio_owned')));
    await waitForIO(tester);
    await tester.tap(find.byKey(const Key('stop_audio_recording')));
    await waitForIO(tester);
    expect((await audio.getPage('solo_audio-ui', 8)).length, 2);
    await tester.tap(find.byKey(const Key('send_audio_message')));
    await waitForIO(tester);
    final updated = await audio.getPage('solo_audio-ui', 8);
    expect(updated.length, 2);
    expect(updated.map((voice) => voice.id), isNot(contains('audio_owned')));
    final newOwn = updated.firstWhere((voice) => voice.senderId == 'owner');
    expect(await File(oldPath).exists(), isFalse);
    expect(await File(newOwn.audioPath).exists(), isTrue);
    expect((await text.getPageText('solo_audio-ui', 8)).single.text,
      'Retain text');
    await tester.ensureVisible(find.byKey(Key('delete_audio_${newOwn.id}')));
    await tester.tap(find.byKey(Key('delete_audio_${newOwn.id}')));
    await waitForIO(tester);
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
