import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/library/pdf_library_screen.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';

import '../../test_helpers.dart';

void main() {
  testWidgets('Library Continue reopens same saved session/page and text after DB restart',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('phase6_library_text_');
    final databaseFile = File('${root.path}/readmesh.sqlite');
    try {
      final db = AppDatabase.forFile(databaseFile);
      await setupLocator(customDatabase: db, customStorageDir: root);
      final pdf = await TestHelpers.createSamplePdfFile(
        File('${root.path}/book.pdf'), pageCount: 12);
      final book = await getIt<BookRepository>().createBook(
        id: 'text-book', title: 'Book', author: 'Offline', filePath: pdf.path,
        fileSize: await pdf.length(), pageCount: 12, sha256Hash: 'resume-text-hash');
      final profile = await getIt<DeviceService>().getOrCreateCurrentProfile();
      const sessionId = 'solo_text-book';
      await getIt<SessionRepository>().createSession(
        id: sessionId, title: 'Solo reading', hostDeviceId: profile.id,
        bookId: book.id, status: 'active');
      await getIt<ReadingProgressRepository>().updateProgress(
        id: 'progress-text', sessionId: sessionId, bookId: book.id,
        deviceId: profile.id, currentPage: 8, totalPages: 12);
      await getIt<MessageRepository>().createText(id: 'saved-text',
        sessionId: sessionId, pageNumber: 8, senderId: profile.id,
        senderName: profile.displayName, text: 'السلام عليكم');
      expect(await getIt<SessionRepository>().saveAndLeaveSession(sessionId,
        lastPage: 8, totalPages: 12), isTrue);
      await resetLocator(); // close SQLite and simulate app exit

      await setupLocator(customDatabase: AppDatabase.forFile(databaseFile),
        customStorageDir: root);
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar'), Locale('en')],
        localizationsDelegates: [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PdfLibraryScreen(),
      ));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 150)));
      await tester.pump();
      final continueButton = find.byKey(const Key('continue_saved_book_text-book'));
      expect(continueButton, findsOneWidget);
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.byType(PdfReaderScreen), findsOneWidget);
      final pageNumber = tester.widget<Text>(
        find.byKey(const Key('page_number_display')));
      expect(pageNumber.data, contains('8'));
      final panel = find.byKey(const Key('text_messages_panel'));
      expect(panel, findsOneWidget);
      final readerScaffold = tester.widget<Scaffold>(
        find.ancestor(of: panel, matching: find.byType(Scaffold)).first);
      expect(readerScaffold.body, isA<LayoutBuilder>());
      expect(find.ancestor(of: panel,
        matching: find.byKey(const Key('reader_vertical_scroll'))),
        findsOneWidget);
      expect(readerScaffold.bottomNavigationBar, isNull);
      expect(find.byKey(const Key('reader_notes_discussion')), findsNothing);
      expect(find.byKey(const Key('reader_highlight')), findsNothing);
      expect(find.text('السلام عليكم'), findsOneWidget);
      expect((await getIt<SessionRepository>().getSessionById(sessionId))?.status,
        'active');
      expect((await getIt<MessageRepository>().getPageText(sessionId, 8))
        .single.text, 'السلام عليكم');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await resetLocator();
      await root.delete(recursive: true);
    }
  });
}
