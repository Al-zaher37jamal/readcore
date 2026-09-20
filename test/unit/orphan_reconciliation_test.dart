import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/orphan_reconciler.dart';
import '../test_helpers.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BookRepository bookRepo;
  late BookFileManager fileManager;
  late OrphanReconciler reconciler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_orphan_test_');
    db = AppDatabase.memory();
    bookRepo = BookRepositoryImpl(db);
    fileManager = BookFileManager(tempDir);
    await fileManager.initialize();
    reconciler = OrphanReconciler(
      fileManager: fileManager,
      bookRepository: bookRepo,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Orphan Reconciliation Tests', () {
    test('Identifies and deletes disk orphan files not registered in SQLite', () async {
      // Create a registered book
      final registeredFile = File(fileManager.getBookFilePath('book-known'));
      await TestHelpers.createSamplePdfFile(registeredFile);
      await bookRepo.createBook(
        id: 'book-known',
        title: 'Registered Book',
        author: 'Author',
        filePath: registeredFile.path,
        fileSize: 100,
        pageCount: 1,
        sha256Hash: 'hash-known',
      );

      // Create an un-tracked orphan file directly on disk
      final orphanFile = File(fileManager.getBookFilePath('orphan-unregistered'));
      await TestHelpers.createSamplePdfFile(orphanFile);

      // Also create a stale temp file
      final staleTemp = File(fileManager.getTempFilePath('stale.tmp'));
      await staleTemp.writeAsString('stale temp file');

      expect((await fileManager.listBookFiles()).length, equals(2));
      expect((await fileManager.listTempFiles()).length, equals(1));

      // Run reconciliation
      final result = await reconciler.reconcile();

      expect(result.reconciledDiskOrphans.length, equals(1));
      expect(result.reconciledDiskOrphans.first, equals(orphanFile.path));
      expect(result.cleanedTempFiles, equals(1));

      // Orphan file must be deleted from disk
      expect(await orphanFile.exists(), isFalse);
      expect(await staleTemp.exists(), isFalse);

      // Registered book must remain intact
      expect(await registeredFile.exists(), isTrue);
      expect((await fileManager.listBookFiles()).length, equals(1));
    });

    test('Identifies database orphan records whose physical files are missing', () async {
      // Create a book in DB pointing to a non-existent file
      await bookRepo.createBook(
        id: 'missing-file-book',
        title: 'Missing File',
        author: 'Ghost Author',
        filePath: '${tempDir.path}/books/does_not_exist.pdf',
        fileSize: 500,
        pageCount: 5,
        sha256Hash: 'hash-ghost',
      );

      final result = await reconciler.reconcile(purgeMissingDbRecords: true);

      expect(result.reconciledDbOrphans, contains('missing-file-book'));

      // Since purgeMissingDbRecords was true, it should now be purged from SQLite
      final allBooks = await bookRepo.getAllBooks();
      expect(allBooks.isEmpty, isTrue);
    });
  });
}
