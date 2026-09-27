import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/audio_message_repository.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/library/pdf_library_screen.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_page_view.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';

import '../../test_helpers.dart';
import 'fake_local_audio_service.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );

  Future<void> waitForIO(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 150)));
    await tester.pump();
  }

  testWidgets('audio controls and commit leave real PDF mounted and page stable',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('phase7_reader_pdf_');
    try {
      await setupLocator(customDatabase: AppDatabase.memory(),
          customStorageDir: root);
      final file = await TestHelpers.createSamplePdfFile(
        File('${root.path}/real.pdf'), pageCount: 12);
      final book = await getIt<BookRepository>().createBook(id: 'voice-pdf',
        title: 'Real PDF', author: 'Local', filePath: file.path,
        fileSize: await file.length(), pageCount: 12,
        sha256Hash: 'voice-pdf-hash');
      final profile = await getIt<DeviceService>().getOrCreateCurrentProfile();
      await getIt<SessionRepository>().createSession(id: 'solo_voice-pdf',
        title: 'Reading', hostDeviceId: profile.id, bookId: book.id,
        status: 'active');
      final fake = FakeLocalAudioService();
      await tester.pumpWidget(app(PdfReaderScreen(book: book,
        sessionId: 'solo_voice-pdf', messageAudioService: fake,
        audioMessageRepository: getIt<AudioMessageRepository>(),
        voiceStore: getIt<SessionVoiceStore>())));
      await waitForIO(tester);
      expect(find.byType(PdfPageView), findsOneWidget);
      expect(find.byKey(const Key('text_messages_panel')), findsOneWidget);
      final viewer = tester.state(find.byType(PdfPageView));
      final currentPage = tester.widget<Text>(
          find.byKey(const Key('page_number_display'))).data;
      final mic = find.byKey(const Key('send_text_message_button'));
      await tester.ensureVisible(mic);
      await tester.tap(mic);
      await waitForIO(tester);
      await tester.tap(find.byKey(const Key('pause_audio_recording')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('resume_audio_recording')));
      await waitForIO(tester);
      await tester.tap(find.byKey(const Key('stop_audio_recording')));
      await waitForIO(tester);
      expect(await getIt<AudioMessageRepository>()
          .getPage('solo_voice-pdf', 1), isEmpty);
      await tester.tap(find.byKey(const Key('send_audio_message')));
      await waitForIO(tester);
      final saved = (await getIt<AudioMessageRepository>()
          .getPage('solo_voice-pdf', 1)).single;
      expect(find.byKey(Key('audio_message_${saved.id}')), findsOneWidget);
      expect(identical(viewer, tester.state(find.byType(PdfPageView))), isTrue);
      expect(tester.widget<Text>(find.byKey(const Key('page_number_display')))
          .data, currentPage);
      final panel = find.byKey(const Key('text_messages_panel'));
      final scaffold = tester.widget<Scaffold>(find.ancestor(
          of: panel, matching: find.byType(Scaffold)).first);
      expect(scaffold.bottomNavigationBar, isNull);
      expect(find.byKey(const Key('reader_notes_discussion')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('next_page_button')));
      await tester.tap(find.byKey(const Key('next_page_button')));
      await waitForIO(tester);
      expect(find.byKey(Key('audio_message_${saved.id}')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('prev_page_button')));
      await tester.tap(find.byKey(const Key('prev_page_button')));
      await waitForIO(tester);
      expect(find.byKey(Key('audio_message_${saved.id}')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await resetLocator();
      await root.delete(recursive: true);
    }
  });

  testWidgets('Library Continue reopens saved page with locally recorded audio',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('phase7_audio_resume_');
    final databaseFile = File('${root.path}/reader.sqlite');
    try {
      await setupLocator(customDatabase: AppDatabase.forFile(databaseFile),
          customStorageDir: root);
      final pdf = await TestHelpers.createSamplePdfFile(
          File('${root.path}/book.pdf'), pageCount: 12);
      final book = await getIt<BookRepository>().createBook(
        id: 'saved-voice', title: 'Saved book', author: 'Offline',
        filePath: pdf.path, fileSize: await pdf.length(), pageCount: 12,
        sha256Hash: 'phase7-saved-voice');
      final profile = await getIt<DeviceService>().getOrCreateCurrentProfile();
      const sessionId = 'solo_saved-voice';
      await getIt<SessionRepository>().createSession(id: sessionId,
        title: 'Reading', hostDeviceId: profile.id, bookId: book.id,
        status: 'active');
      final store = getIt<SessionVoiceStore>();
      final pending = await store.fileFor(sessionId, 'draft_audio_saved');
      await pending.writeAsBytes(List<int>.filled(256, 41), flush: true);
      final saved = await getIt<AudioMessageRepository>().send(
        id: 'audio_saved', sessionId: sessionId, pageNumber: 8,
        senderId: profile.id, senderDisplayName: 'أحمد',
        draft: pending, durationMs: 2500);
      await getIt<SessionRepository>().saveAndLeaveSession(sessionId,
        lastPage: 8, totalPages: 12);
      await resetLocator(); // close DB, simulate application exit

      await setupLocator(customDatabase: AppDatabase.forFile(databaseFile),
          customStorageDir: root); // startup GC preserves referenced audio
      await tester.pumpWidget(app(const PdfLibraryScreen()));
      await waitForIO(tester);
      final continueButton = find.byKey(
          const Key('continue_saved_book_saved-voice'));
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await waitForIO(tester);
      expect(find.byType(PdfReaderScreen), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('page_number_display')))
          .data, contains('8'));
      expect(find.byKey(Key('audio_message_${saved.id}')), findsOneWidget);
      expect(await File(saved.audioPath).exists(), isTrue);
      expect((await getIt<AudioMessageRepository>()
        .getPage(sessionId, 8)).single.id, saved.id);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await resetLocator();
      await root.delete(recursive: true);
    }
  });
}
