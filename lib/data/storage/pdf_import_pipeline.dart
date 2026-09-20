import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:readmesh/core/constants/app_constants.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/pdf_inspector.dart';

/// Service orchestrating the secure, atomic import of PDF documents.
class PdfImportPipeline {
  final BookFileManager _fileManager;
  final BookRepository _bookRepository;
  final DiskSpaceChecker _diskSpaceChecker;
  final PdfInspector _pdfInspector;
  final Uuid _uuid;

  PdfImportPipeline({
    required BookFileManager fileManager,
    required BookRepository bookRepository,
    DiskSpaceChecker? diskSpaceChecker,
    PdfInspector? pdfInspector,
    Uuid? uuid,
  })  : _fileManager = fileManager,
        _bookRepository = bookRepository,
        _diskSpaceChecker = diskSpaceChecker ?? const SystemDiskSpaceChecker(),
        _pdfInspector = pdfInspector ?? const PdfInspector(),
        _uuid = uuid ?? const Uuid();

  /// Executes the full PDF import pipeline.
  ///
  /// Steps:
  /// 1. Pre-flight file size check (< 300 MB)
  /// 2. Available storage validation (file size + 50 MB buffer)
  /// 3. Atomic streaming copy to temporary file while calculating SHA-256
  /// 4. Duplicate verification against SQLite
  /// 5. PDF header and page count validation (< ~10,000 pages)
  /// 6. Atomic move to books directory
  /// 7. Persist metadata into SQLite (no binary data in DB!)
  Future<Book> importBook({
    required File sourceFile,
    String? title,
    String? author,
    String? coverPath,
  }) async {
    if (!await sourceFile.exists()) {
      throw const NotFoundException('Source PDF file does not exist.');
    }

    // Step 1: Pre-flight file size verification
    final fileSize = await sourceFile.length();
    if (fileSize > AppConstants.maxPdfSizeBytes) {
      throw FileTooLargeException(fileSize, AppConstants.maxPdfSizeBytes);
    }

    await _fileManager.ensureDirectoriesExist();

    // Step 2: Available storage space validation
    final requiredSpace = fileSize + AppConstants.minDiskSpaceBufferBytes;
    final availableSpace = await _diskSpaceChecker.getAvailableDiskSpace(
      _fileManager.booksDir.path,
    );

    if (availableSpace < requiredSpace) {
      throw InsufficientStorageException(requiredSpace, availableSpace);
    }

    // Step 3: Stream to temporary file while computing SHA-256
    final tempFileName = 'import_${_uuid.v4()}.tmp';
    final tempFilePath = _fileManager.getTempFilePath(tempFileName);
    final tempFile = File(tempFilePath);

    int bytesWritten = 0;
    String sha256Hash = '';
    final shaSink = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((digests) {
        if (digests.isNotEmpty) {
          sha256Hash = digests.single.toString();
        }
      }),
    );

    IOSink? outSink;
    try {
      outSink = tempFile.openWrite();
      final inStream = sourceFile.openRead();

      await for (final chunk in inStream) {
        bytesWritten += chunk.length;
        if (bytesWritten > AppConstants.maxPdfSizeBytes) {
          throw FileTooLargeException(bytesWritten, AppConstants.maxPdfSizeBytes);
        }
        shaSink.add(chunk);
        outSink.add(chunk);
      }

      await outSink.flush();
      await outSink.close();
      outSink = null;
      shaSink.close();

      // Step 4: Duplicate verification against SQLite
      final existingBook = await _bookRepository.getBookBySha256(sha256Hash);
      if (existingBook != null) {
        throw DuplicateBookException(sha256Hash);
      }

      // Step 5: PDF format & page count inspection
      final pageCount = await _pdfInspector.inspectPageCount(tempFile);

      // Step 6: Atomic move to books directory
      final bookId = _uuid.v4();
      final destinationPath = _fileManager.getBookFilePath(bookId);
      final destinationFile = File(destinationPath);

      try {
        await tempFile.rename(destinationPath);
      } on FileSystemException {
        // Fallback for cross-device moves
        await tempFile.copy(destinationPath);
        await tempFile.delete();
      }

      // Step 7: Persist metadata in SQLite (only metadata and file path, never binary!)
      final bookTitle = title ?? p.basenameWithoutExtension(sourceFile.path);
      final bookAuthor = author ?? 'Unknown';

      try {
        final book = await _bookRepository.createBook(
          id: bookId,
          title: bookTitle,
          author: bookAuthor,
          filePath: destinationPath,
          fileSize: bytesWritten,
          pageCount: pageCount,
          sha256Hash: sha256Hash,
          coverPath: coverPath,
        );
        return book;
      } catch (dbError) {
        // Rollback physical destination file if database insertion fails
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }
        rethrow;
      }
    } catch (e) {
      // Ensure temp file is cleaned up on any failure
      try {
        if (outSink != null) {
          await outSink.close();
        }
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }
}
