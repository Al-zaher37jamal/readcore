import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import '../../test_helpers.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BookRepository bookRepo;
  late ReadingProgressRepository progressRepo;
  late SessionRepository sessionRepo;
  late DeviceService deviceService;
  late Book testBook;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_widget_test_');
    db = AppDatabase.memory();
    bookRepo = BookRepositoryImpl(db);
    progressRepo = ReadingProgressRepositoryImpl(db);
    sessionRepo = SessionRepositoryImpl(db);
    final profileRepo = DeviceProfileRepositoryImpl(db);
    deviceService = DeviceService(repository: profileRepo);

    await deviceService.getOrCreateCurrentProfile();

    final pdfFile = File('${tempDir.path}/test_book.pdf');
    await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 5);

    testBook = await bookRepo.createBook(
      id: 'book-widget-1',
      title: 'Widget Testing Handbook',
      author: 'Flutter Team',
      filePath: pdfFile.path,
      fileSize: 1024,
      pageCount: 5,
      sha256Hash: 'hash-w1',
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('PdfReaderScreen renders pages, navigates next/prev, and saves/restores progress',
      (WidgetTester tester) async {
    // 1. Pump the reader widget
    await tester.pumpWidget(
      MaterialApp(
        home: PdfReaderScreen(
          book: testBook,
          readingProgressRepository: progressRepo,
          deviceService: deviceService,
          sessionRepository: sessionRepo,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify Title and initial Page Number
    expect(find.text('Widget Testing Handbook'), findsWidgets);
    expect(find.text('Page 1 of 5'), findsWidgets);

    // Verify Previous button is disabled on Page 1
    final prevButtonFinder = find.byKey(const Key('prev_page_button'));
    final prevIconButton = tester.widget<IconButton>(prevButtonFinder);
    expect(prevIconButton.onPressed, isNull);

    // 2. Tap Next button to go to Page 2
    final nextButtonFinder = find.byKey(const Key('next_page_button'));
    await tester.tap(nextButtonFinder);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Page 2 of 5'), findsWidgets);

    // 3. Tap Next button to go to Page 3
    await tester.tap(nextButtonFinder);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('Page 3 of 5'), findsWidgets);

    // 4. Verify progress was saved to SQLite
    final profile = await deviceService.getOrCreateCurrentProfile();
    final savedProgress = await progressRepo.getLatestBookProgress(testBook.id, profile.id);
    expect(savedProgress, isNotNull);
    expect(savedProgress!.currentPage, equals(3));

    // 5. Re-open reader in a new widget pump and verify last page (Page 3) is restored!
    await tester.pumpWidget(
      MaterialApp(
        home: PdfReaderScreen(
          book: testBook,
          readingProgressRepository: progressRepo,
          deviceService: deviceService,
          sessionRepository: sessionRepo,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verifies Page 3 was restored from SQLite!
    expect(find.text('Page 3 of 5'), findsWidgets);
  });
}
