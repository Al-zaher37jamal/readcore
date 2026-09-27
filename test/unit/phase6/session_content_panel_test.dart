import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'package:readmesh/features/session_content/session_content_panel.dart';
import 'package:readmesh/features/session_content/voice_audio_service.dart';

class _FakeAudio implements VoiceAudioService {
  String? started, played;
  int cancels = 0;
  @override
  Future<bool> start(String absolutePath) async {
    started = absolutePath;
    await File(absolutePath).writeAsBytes([1, 2, 3, 4, 5, 6, 7]);
    return true;
  }
  @override
  Future<int> stop() async => 1250;
  @override
  Future<void> cancel() async { cancels++; }
  @override
  Future<void> play(String absolutePath) async { played = absolutePath; }
  @override
  Future<void> stopPlayback() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late AppDatabase db;
  late SessionContentRepository repository;
  late SessionContentSync sync;
  late _FakeAudio audio;
  const id = 'solo_panel-book';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('phase6_panel_');
    db = AppDatabase.memory();
    repository = SessionContentRepository(db);
    await BookRepositoryImpl(db).createBook(id: 'panel-book', title: 'PDF',
        author: 'A', filePath: '${temp.path}/book.pdf', fileSize: 100,
        pageCount: 20, sha256Hash: 'panel-hash');
    await SessionRepositoryImpl(db).createSession(id: id, title: 'Solo',
        hostDeviceId: 'phone-a', bookId: 'panel-book', status: 'active');
    sync = SessionContentSync(sessionId: id, bookId: 'panel-book',
        deviceId: 'phone-a', displayName: 'Reader', totalPages: 20,
        repository: repository, voiceStore: SessionVoiceStore(temp))..start();
    audio = _FakeAudio();
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
    await temp.delete(recursive: true);
  });

  Widget panel(int page, {bool isGroup = false}) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [AppLocalizationsDelegate()],
    home: Scaffold(body: SizedBox(height: 650,
      child: SessionContentPanel(sync: sync, pageNumber: page,
          canEdit: true, isGroup: isGroup, audioService: audio))),
  );

  testWidgets('notes are page-scoped; pin, shared switch, discussion and emoji',
      (tester) async {
    await sync.addNote(4, 'Not on page five', shared: false);
    await tester.pumpWidget(panel(5, isGroup: true));
    await tester.pumpAndSettle();
    expect(find.text('Not on page five'), findsNothing);
    expect(find.byType(Scrollbar), findsWidgets);
    await tester.enterText(find.byKey(const Key('new_page_note')),
        'ملاحظتي الخاصة');
    await tester.tap(find.byKey(const Key('save_page_note')));
    await tester.pumpAndSettle();
    expect(find.text('ملاحظتي الخاصة'), findsOneWidget);
    final personal = (await repository.watchAnnotations(id, 5, 'phone-a').first)
        .single;
    expect(personal.visibility, 'personal');
    await tester.tap(find.byKey(Key('pin_note_${personal.id}')));
    await tester.pumpAndSettle();
    expect((await repository.watchAnnotations(id, 5, 'phone-a').first)
        .single.isPinned, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('new_page_note')), 'Public');
    await tester.tap(find.byKey(const Key('save_page_note')));
    await tester.pumpAndSettle();
    expect((await repository.watchAnnotations(id, 5, 'stranger').first)
        .single.content, 'Public');
    await tester.tap(find.text('Discussion'));
    await tester.pumpAndSettle();
    expect(find.byType(Scrollbar), findsWidgets);
    await tester.enterText(find.byKey(const Key('new_page_message')), 'أهلاً');
    await tester.tap(find.text('👍'));
    await tester.tap(find.byKey(const Key('send_page_message')));
    await tester.pumpAndSettle();
    expect((await repository.watchDiscussion(id, 5).first).single.content,
        'أهلاً👍');
    expect(await repository.watchDiscussion(id, 4).first, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('local recording can cancel or save to file, then play',
      (tester) async {
    await tester.pumpWidget(panel(8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discussion'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start_voice_recording')));
    await tester.pumpAndSettle();
    final canceledFile = File(audio.started!);
    expect(find.byKey(const Key('recording_elapsed_time')), findsOneWidget);
    expect(await canceledFile.exists(), isTrue);
    await tester.tap(find.byKey(const Key('cancel_voice_recording')));
    await tester.pumpAndSettle();
    expect(await canceledFile.exists(), isFalse);
    expect(await repository.watchDiscussion(id, 8).first, isEmpty);

    await tester.tap(find.byKey(const Key('start_voice_recording')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stop_voice_recording')));
    await tester.pumpAndSettle();
    final voice = (await repository.watchDiscussion(id, 8).first).single;
    expect(voice.kind, 'voice');
    expect(voice.durationMs, 1250);
    expect(await File(voice.voicePath!).exists(), isTrue);
    await tester.tap(find.byKey(Key('play_voice_${voice.id}')));
    await tester.pumpAndSettle();
    expect(audio.played, voice.voicePath);
    expect(audio.cancels, greaterThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('read-only history shows notes but no edit controls',
      (tester) async {
    await sync.addNote(8, 'Preserved after Save & Leave', shared: false);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      height: 650,
      child: SessionContentPanel(sync: sync, pageNumber: 8,
          canEdit: false, isGroup: false, audioService: audio),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Preserved after Save & Leave'), findsOneWidget);
    expect(find.byKey(const Key('new_page_note')), findsNothing);
    await tester.tap(find.text('نقاش'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start_voice_recording')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
