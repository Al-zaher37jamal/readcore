import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/core/theme/app_theme.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_reading_timer_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_page_view.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import 'package:readmesh/features/reading_time/domain/session_reading_timer.dart';
import 'package:readmesh/features/reading_time/presentation/session_reading_timer_controller.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_panel.dart';

import '../../test_helpers.dart';

void main() {
  Future<void> waitForWidget(WidgetTester tester, Finder finder,
      String step) async {
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < const Duration(seconds: 5)) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 50)));
      await tester.pump();
      final error = tester.takeException();
      if (error != null) fail('Flutter exception during $step: $error');
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $step');
  }

  testWidgets('configure/start/finish changes badge only: PDF, page and discussion survive',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('phase8_reader_timer_');
    SessionReadingTimerController? timer;
    const sessionId = 'solo_phase8_timer';
    var now = DateTime.utc(2026, 9, 26, 12);
    try {
      await setupLocator(customDatabase: AppDatabase.memory(),
          customStorageDir: root);
      final pdf = await TestHelpers.createSamplePdfFile(
          File('${root.path}/real.pdf'), pageCount: 12);
      final book = await getIt<BookRepository>().createBook(id: 'timer-pdf',
          title: 'Real PDF', author: 'Local', filePath: pdf.path,
          fileSize: await pdf.length(), pageCount: 12,
          sha256Hash: 'phase8-timer-pdf');
      final profile = await getIt<DeviceService>().getOrCreateCurrentProfile();
      final sessions = getIt<SessionRepository>();
      await sessions.createSession(id: sessionId, title: 'Reading',
          hostDeviceId: profile.id, bookId: book.id, status: 'active');
      final repository = SessionReadingTimerRepositoryImpl(
          getIt<AppDatabase>(), now: () => now);
      final controller = SessionReadingTimerController(repository: repository,
          sessionRepository: sessions, sessionId: sessionId,
          actorDeviceId: profile.id, now: () => now);
      timer = controller;
      await controller.load();
      await getIt<MessageRepository>().createText(id: 'keep-phase8',
          sessionId: sessionId, pageNumber: 2, senderId: profile.id,
          senderName: 'Local reader', text: 'Keep discussion');

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PdfReaderScreen(book: book, sessionId: sessionId,
            sessionReadingTimerController: controller),
      ));
      await waitForWidget(tester, find.byType(PdfPageView), 'real PDF view');
      await tester.ensureVisible(find.byKey(const Key('next_page_button')));
      await tester.tap(find.byKey(const Key('next_page_button')));
      await tester.pump();
      await waitForWidget(tester, find.text('Keep discussion'),
          'page 2 text discussion');
      final pdfState = tester.state(find.byType(PdfPageView));
      final messageState = tester.state(find.byType(TextMessagesPanel));
      final page = tester.widget<Text>(find.byKey(
          const Key('page_number_display'))).data;
      expect(page, 'Page 2 of 12');

      await tester.runAsync(() => controller.configure(1));
      await tester.pump();
      await tester.runAsync(() => controller.start());
      await tester.pump();
      expect(controller.status, ReadingTimerStatus.running);
      expect(identical(pdfState, tester.state(find.byType(PdfPageView))), isTrue);
      expect(identical(messageState,
          tester.state(find.byType(TextMessagesPanel))), isTrue);
      expect(tester.widget<Text>(find.byKey(const Key('page_number_display')))
          .data, page);
      expect(find.text('Keep discussion'), findsOneWidget);

      now = now.add(const Duration(minutes: 1));
      controller.refresh();
      await tester.runAsync(() => repository.watch(sessionId)
          .firstWhere((value) => value?.status == ReadingTimerStatus.finished)
          .timeout(const Duration(seconds: 5)));
      await waitForWidget(tester, find.text('Reading time finished'),
          'finished timer badge');
      expect(tester.widget<Text>(find.byKey(const Key('reading_time_status')))
          .data, 'Reading time finished');
      expect((tester.widget<Container>(find.byKey(
          const Key('reading_time_badge'))).decoration as BoxDecoration).color,
          AppTheme.softSuccess);
      expect(identical(pdfState, tester.state(find.byType(PdfPageView))), isTrue);
      expect(identical(messageState,
          tester.state(find.byType(TextMessagesPanel))), isTrue);
      expect(tester.widget<Text>(find.byKey(const Key('page_number_display')))
          .data, page);
      expect(find.text('Keep discussion'), findsOneWidget);
      expect((await getIt<MessageRepository>().getPageText(sessionId, 2))
          .single.text, 'Keep discussion');
      expect((await sessions.getSessionById(sessionId))!.status, 'active');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      timer?.dispose();
      if (getIt.isRegistered<AppDatabase>()) await resetLocator();
      await root.delete(recursive: true);
    }
  });
}
