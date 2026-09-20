import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/constants/app_constants.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/note_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/orphan_reconciler.dart';
import 'package:readmesh/data/storage/pdf_import_pipeline.dart';
import 'package:readmesh/data/storage/storage_manager.dart';
import '../test_helpers.dart';

void main() {
  late Directory tempDir;
  late MockDiskSpaceChecker diskSpaceChecker;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_phase2_integ_');
    diskSpaceChecker = MockDiskSpaceChecker(1024 * 1024 * 1024); // 1 GB available

    dbFile = File('${tempDir.path}/${AppConstants.databaseName}');
    final db = AppDatabase.forFile(dbFile);

    await setupLocator(
      customDatabase: db,
      customDatabaseFile: dbFile,
      customStorageDir: tempDir,
      customDiskSpaceChecker: diskSpaceChecker,
      runIntegrityCheck: true,
    );
  });

  tearDown(() async {
    await resetLocator();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 2 SQLite + Local Storage Full Integration Pipeline', () {
    test('End-to-end import, storage management, session reading, and orphan reconciliation', () async {
      final pipeline = getIt<PdfImportPipeline>();
      final bookRepo = getIt<BookRepository>();
      final sessionRepo = getIt<SessionRepository>();
      final memberRepo = getIt<SessionMemberRepository>();
      final noteRepo = getIt<NoteRepository>();
      final storageManager = getIt<StorageManager>();
      final orphanReconciler = getIt<OrphanReconciler>();
      final db = getIt<AppDatabase>();

      // 1. Create a sample valid PDF
      final sourcePdf = File('${tempDir.path}/source_book.pdf');
      await TestHelpers.createSamplePdfFile(sourcePdf, pageCount: 25);

      // 2. Import book via pipeline
      final importedBook = await pipeline.importBook(
        sourceFile: sourcePdf,
        title: 'Distributed Systems',
        author: 'Maarten van Steen',
      );

      expect(importedBook.title, equals('Distributed Systems'));
      expect(importedBook.pageCount, equals(25));
      expect(importedBook.sha256Hash.isNotEmpty, isTrue);

      // 3. Verify SQLite stored NO binary data (only metadata and file path)
      final bookInDb = await bookRepo.getBookById(importedBook.id);
      expect(bookInDb, isNotNull);
      expect(bookInDb!.filePath, equals(importedBook.filePath));
      expect(await File(bookInDb.filePath).exists(), isTrue);

      final pragmaColumns = await db.customSelect("PRAGMA table_info('books');").get();
      for (final col in pragmaColumns) {
        final colType = (col.data['type'] as String).toUpperCase();
        expect(colType, isNot(contains('BLOB')));
      }

      // 4. Verify duplicate book rejection
      await expectLater(
        () => pipeline.importBook(sourceFile: sourcePdf),
        throwsA(isA<DuplicateBookException>()),
      );

      // 5. Create a reading session with members and notes
      final session = await sessionRepo.createSession(
        id: 'session-integ-1',
        title: 'Study Session 1',
        hostDeviceId: 'dev-integ-1',
        bookId: importedBook.id,
        status: 'active',
      );

      await memberRepo.addMember(
        id: 'mem-integ-1',
        sessionId: session.id,
        deviceId: 'dev-integ-1',
        displayName: 'Host User',
        role: 'host',
        status: 'active',
      );

      await noteRepo.createNote(
        id: 'note-integ-1',
        bookId: importedBook.id,
        pageNumber: 10,
        deviceId: 'dev-integ-1',
        authorName: 'Host User',
        content: 'Crucial concept regarding consensus.',
        color: '#00E676',
      );

      final sessionNotes = await noteRepo.getNotesForBook(importedBook.id);
      expect(sessionNotes.length, equals(1));
      expect(sessionNotes.first.content, contains('consensus'));

      // 6. Test storage usage reporting
      final usage = await storageManager.getStorageUsage();
      expect(usage.books, isPositive);
      expect(usage.database, isPositive);
      expect(usage.total, equals(usage.books + usage.cache + usage.database));
      expect(usage.available, equals(1024 * 1024 * 1024));

      // Verify no audio field in report
      final reportMap = usage.toMap();
      expect(reportMap.containsKey('audio'), isFalse);
      expect(reportMap.keys.toSet(), equals({'books', 'cache', 'database', 'total', 'available'}));

      // 7. Test orphan reconciliation with an unindexed file
      final orphanFile = File('${tempDir.path}/books/unregistered_file.pdf');
      await orphanFile.writeAsString('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF');

      final reconciliation = await orphanReconciler.reconcile();
      expect(reconciliation.reconciledDiskOrphans.length, equals(1));
      expect(await orphanFile.exists(), isFalse);

      // The registered imported book file must still exist
      expect(await File(importedBook.filePath).exists(), isTrue);
    });
  });
}
