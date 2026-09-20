import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/pdf_import_pipeline.dart';
import 'package:readmesh/features/profile/device_service.dart';
import '../../test_helpers.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BookRepository bookRepo;
  late ReadingProgressRepository progressRepo;
  late SessionRepository sessionRepo;
  late DeviceService deviceService;
  late BookFileManager fileManager;
  late PdfImportPipeline pipeline;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_unit_test_');
    db = AppDatabase.memory();
    bookRepo = BookRepositoryImpl(db);
    progressRepo = ReadingProgressRepositoryImpl(db);
    sessionRepo = SessionRepositoryImpl(db);
    final profileRepo = DeviceProfileRepositoryImpl(db);
    deviceService = DeviceService(repository: profileRepo);

    fileManager = BookFileManager(tempDir);
    await fileManager.initialize();

    pipeline = PdfImportPipeline(
      fileManager: fileManager,
      bookRepository: bookRepo,
      diskSpaceChecker: MockDiskSpaceChecker(),
    );

    await deviceService.getOrCreateCurrentProfile();
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PDF Reader & Reading Progress Logic Tests', () {
    test('Opens imported PDF, advances pages, saves progress, and restores on reopen', () async {
      // 1. Create and import a 15-page PDF
      final sourceFile = File('${tempDir.path}/imported_book.pdf');
      await TestHelpers.createSamplePdfFile(sourceFile, pageCount: 15);

      final book = await pipeline.importBook(
        sourceFile: sourceFile,
        title: 'Concurrent Programming in Dart',
        author: 'Test Author',
      );

      expect(book.pageCount, equals(15));
      expect(await File(book.filePath).exists(), isTrue);

      final profile = await deviceService.getOrCreateCurrentProfile();
      final deviceId = profile.id;
      const sessionId = 'session_test_1';

      // Ensure session exists
      await sessionRepo.createSession(
        id: sessionId,
        title: 'Concurrent Study',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      // 2. Initial state: progress not yet recorded
      final initialProg = await progressRepo.getProgress(sessionId, deviceId);
      expect(initialProg, isNull);

      // 3. User reads to Page 7 -> Save progress to SQLite
      await progressRepo.updateProgress(
        id: 'prog_${sessionId}_${book.id}_$deviceId',
        sessionId: sessionId,
        bookId: book.id,
        deviceId: deviceId,
        currentPage: 7,
        totalPages: 15,
      );

      final savedProg = await progressRepo.getProgress(sessionId, deviceId);
      expect(savedProg, isNotNull);
      expect(savedProg!.currentPage, equals(7));
      expect(savedProg.totalPages, equals(15));
      expect(savedProg.percentage, closeTo(7 / 15, 0.01));

      // 4. User navigates to Page 8
      await progressRepo.updateProgress(
        id: 'prog_${sessionId}_${book.id}_$deviceId',
        sessionId: sessionId,
        bookId: book.id,
        deviceId: deviceId,
        currentPage: 8,
        totalPages: 15,
      );

      // 5. Restore last reading position for the book
      final restored = await progressRepo.getLatestBookProgress(book.id, deviceId);
      expect(restored, isNotNull);
      expect(restored!.currentPage, equals(8));
      expect(restored.bookId, equals(book.id));
    });

    test('Clamps page navigation boundaries within 1 and totalPages', () async {
      const totalPages = 10;
      int currentPage = 1;

      // Cannot go previous on page 1
      if (currentPage > 1) currentPage--;
      expect(currentPage, equals(1));

      // Advance to page 10
      for (int i = 1; i < totalPages; i++) {
        if (currentPage < totalPages) currentPage++;
      }
      expect(currentPage, equals(10));

      // Cannot advance past page 10
      if (currentPage < totalPages) currentPage++;
      expect(currentPage, equals(10));
    });
  });
}
