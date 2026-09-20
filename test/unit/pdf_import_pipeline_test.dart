import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/pdf_import_pipeline.dart';
import 'package:readmesh/data/storage/pdf_inspector.dart';
import '../test_helpers.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BookRepository bookRepo;
  late BookFileManager fileManager;
  late MockDiskSpaceChecker diskSpaceChecker;
  late PdfImportPipeline pipeline;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_pipeline_test_');
    db = AppDatabase.memory();
    bookRepo = BookRepositoryImpl(db);
    fileManager = BookFileManager(tempDir);
    await fileManager.initialize();
    diskSpaceChecker = MockDiskSpaceChecker(10 * 1024 * 1024 * 1024); // 10 GB
    pipeline = PdfImportPipeline(
      fileManager: fileManager,
      bookRepository: bookRepo,
      diskSpaceChecker: diskSpaceChecker,
      pdfInspector: const PdfInspector(),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PdfImportPipeline Tests', () {
    test('Successfully imports a valid PDF, computes SHA-256, and stores only metadata', () async {
      final samplePdf = File(p.join(tempDir.path, 'source_sample.pdf'));
      await TestHelpers.createSamplePdfFile(samplePdf, pageCount: 12);

      final book = await pipeline.importBook(
        sourceFile: samplePdf,
        title: 'Mastering ReadMesh',
        author: 'Mesh Architect',
      );

      expect(book.title, equals('Mastering ReadMesh'));
      expect(book.author, equals('Mesh Architect'));
      expect(book.pageCount, equals(12));
      expect(book.sha256Hash.isNotEmpty, isTrue);
      // Platform-independent check: book path should be under books directory
      expect(p.split(book.filePath).contains('books'), isTrue);
      expect(p.basename(p.dirname(book.filePath)), equals('books'));

      // Check physical file exists in books directory
      expect(await File(book.filePath).exists(), isTrue);

      // Verify no temporary files remain
      final tempFiles = await fileManager.listTempFiles();
      expect(tempFiles.isEmpty, isTrue);

      // Verify SQLite row contains NO binary data
      final row = await (db.select(db.booksTable)..where((t) => t.id.equals(book.id))).getSingle();
      expect(row.filePath, equals(book.filePath));
      expect(row.fileSize, equals(await samplePdf.length()));
    });

    test('Rejects PDF files larger than 300 MB limit', () async {
      final oversizedPdf = File(p.join(tempDir.path, 'oversized.pdf'));
      await TestHelpers.createOversizedPdfFile(oversizedPdf, sizeBytes: 301 * 1024 * 1024);

      await expectLater(
        () => pipeline.importBook(sourceFile: oversizedPdf),
        throwsA(isA<FileTooLargeException>()),
      );

      // Verify temp files cleaned up
      final tempFiles = await fileManager.listTempFiles();
      expect(tempFiles.isEmpty, isTrue);
    });

    test('Rejects PDFs exceeding approximately 10,000 pages', () async {
      final hugePagesPdf = File(p.join(tempDir.path, 'huge_pages.pdf'));
      await TestHelpers.createSamplePdfFile(hugePagesPdf, pageCount: 10001);

      await expectLater(
        () => pipeline.importBook(sourceFile: hugePagesPdf),
        throwsA(isA<PageCountExceededException>()),
      );

      // Verify temp files cleaned up
      final tempFiles = await fileManager.listTempFiles();
      expect(tempFiles.isEmpty, isTrue);
    });

    test('Validates available disk space and rejects if storage is insufficient', () async {
      final samplePdf = File(p.join(tempDir.path, 'normal.pdf'));
      await TestHelpers.createSamplePdfFile(samplePdf, pageCount: 5);

      // Simulate only 1 MB available disk space
      diskSpaceChecker.availableBytes = 1 * 1024 * 1024;

      await expectLater(
        () => pipeline.importBook(sourceFile: samplePdf),
        throwsA(isA<InsufficientStorageException>()),
      );

      // Verify temp files cleaned up
      final tempFiles = await fileManager.listTempFiles();
      expect(tempFiles.isEmpty, isTrue);
    });

    test('Rejects duplicate PDF imports by detecting matching SHA-256 checksum', () async {
      final samplePdf = File(p.join(tempDir.path, 'duplicate_candidate.pdf'));
      await TestHelpers.createSamplePdfFile(samplePdf, pageCount: 3);

      // First import succeeds
      await pipeline.importBook(sourceFile: samplePdf);

      // Second import with same file/hash must throw DuplicateBookException
      await expectLater(
        () => pipeline.importBook(sourceFile: samplePdf),
        throwsA(isA<DuplicateBookException>()),
      );
    });

    test('Rolls back atomically on failure and cleans up all temporary artifacts', () async {
      final corruptPdf = File(p.join(tempDir.path, 'corrupt.pdf'));
      await corruptPdf.writeAsString('Definitely not a PDF content');

      await expectLater(
        () => pipeline.importBook(sourceFile: corruptPdf),
        throwsA(isA<InvalidPdfException>()),
      );

      // Verify no book in database
      final allBooks = await bookRepo.getAllBooks();
      expect(allBooks.isEmpty, isTrue);

      // Verify no files in books or temp directory
      expect((await fileManager.listBookFiles()).isEmpty, isTrue);
      expect((await fileManager.listTempFiles()).isEmpty, isTrue);
    });
  });
}
