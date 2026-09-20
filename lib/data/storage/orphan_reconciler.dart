import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';

class OrphanReconciliationResult {
  final List<String> reconciledDiskOrphans;
  final List<String> reconciledDbOrphans;
  final int cleanedTempFiles;

  const OrphanReconciliationResult({
    required this.reconciledDiskOrphans,
    required this.reconciledDbOrphans,
    required this.cleanedTempFiles,
  });

  bool get hasOrphans =>
      reconciledDiskOrphans.isNotEmpty || reconciledDbOrphans.isNotEmpty;

  @override
  String toString() {
    return 'OrphanReconciliationResult(diskOrphans: ${reconciledDiskOrphans.length}, '
        'dbOrphans: ${reconciledDbOrphans.length}, tempFilesCleaned: $cleanedTempFiles)';
  }
}

/// Service to detect and reconcile orphan files on disk and orphaned records in SQLite.
class OrphanReconciler {
  final BookFileManager _fileManager;
  final BookRepository _bookRepository;

  OrphanReconciler({
    required BookFileManager fileManager,
    required BookRepository bookRepository,
  })  : _fileManager = fileManager,
        _bookRepository = bookRepository;

  /// Runs the orphan reconciliation process.
  ///
  /// 1. Finds and removes files on disk that have no matching book in SQLite.
  /// 2. Finds book records in SQLite whose physical files no longer exist on disk (and optionally purges them).
  /// 3. Cleans up any stale temporary files.
  Future<OrphanReconciliationResult> reconcile({
    bool purgeMissingDbRecords = false,
  }) async {
    await _fileManager.ensureDirectoriesExist();

    final diskOrphans = <String>[];
    final dbOrphans = <String>[];

    // Step 1: Query all registered books from SQLite
    final registeredBooks = await _bookRepository.getAllBooks();
    final registeredFilePaths = registeredBooks.map((b) => p.normalize(b.filePath)).toSet();
    final registeredFileNames = registeredBooks.map((b) => p.basename(b.filePath)).toSet();

    // Step 2: Scan physical books directory
    final physicalFiles = await _fileManager.listBookFiles();
    for (final file in physicalFiles) {
      final normalizedPath = p.normalize(file.path);
      final fileName = p.basename(file.path);

      final isKnown = registeredFilePaths.contains(normalizedPath) ||
          registeredFileNames.contains(fileName);

      if (!isKnown) {
        // Disk orphan: file exists on disk, but has no record in SQLite
        diskOrphans.add(file.path);
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    // Step 3: Check for Database orphans (records with missing physical files)
    for (final book in registeredBooks) {
      final file = File(book.filePath);
      if (!await file.exists()) {
        dbOrphans.add(book.id);
        if (purgeMissingDbRecords) {
          await _bookRepository.deleteBook(book.id);
        }
      }
    }

    // Step 4: Clean up any stale temporary files
    final tempCleaned = await _fileManager.clearTempDirectory();

    return OrphanReconciliationResult(
      reconciledDiskOrphans: diskOrphans,
      reconciledDbOrphans: dbOrphans,
      cleanedTempFiles: tempCleaned,
    );
  }
}
