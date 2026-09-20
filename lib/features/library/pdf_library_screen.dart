import 'dart:io';
import 'package:flutter/material.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/pdf_import_pipeline.dart';
import 'package:readmesh/data/storage/storage_manager.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';

/// Screen displaying the local library of imported PDF books with reading progress
/// and import triggers. FIXED: DuplicateBookException friendly Arabic/English dialog.
class PdfLibraryScreen extends StatefulWidget {
  final BookRepository? bookRepository;
  final ReadingProgressRepository? readingProgressRepository;
  final PdfImportPipeline? pdfImportPipeline;
  final DeviceService? deviceService;
  final BookFileManager? bookFileManager;

  const PdfLibraryScreen({
    super.key,
    this.bookRepository,
    this.readingProgressRepository,
    this.pdfImportPipeline,
    this.deviceService,
    this.bookFileManager,
  });

  @override
  State<PdfLibraryScreen> createState() => _PdfLibraryScreenState();
}

class _PdfLibraryScreenState extends State<PdfLibraryScreen> {
  late final BookRepository _bookRepo;
  late final ReadingProgressRepository _progressRepo;
  late final PdfImportPipeline _importPipeline;
  late final DeviceService _deviceService;
  late final BookFileManager _fileManager;

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _bookRepo = widget.bookRepository ?? getIt<BookRepository>();
    _progressRepo = widget.readingProgressRepository ?? getIt<ReadingProgressRepository>();
    _importPipeline = widget.pdfImportPipeline ?? getIt<PdfImportPipeline>();
    _deviceService = widget.deviceService ?? getIt<DeviceService>();
    _fileManager = widget.bookFileManager ?? getIt<BookFileManager>();
  }

  /// Imports a sample PDF book into the local library for immediate reading.
  Future<void> _importSampleBook({int pageCount = 20, String title = 'Flutter Architecture Guide'}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isImporting = true;
    });

    try {
      await _fileManager.ensureDirectoriesExist();
      final tempFile = File(_fileManager.getTempFilePath('sample_${DateTime.now().millisecondsSinceEpoch}.pdf'));

      // Create a valid sample PDF with requested page count
      final buffer = StringBuffer();
      buffer.write('%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');

      final kids = <String>[];
      for (int i = 0; i < pageCount; i++) {
        kids.add('${3 + i} 0 R');
      }
      buffer.write('2 0 obj\n<< /Type /Pages /Kids [${kids.join(' ')}] /Count $pageCount >>\nendobj\n');

      for (int i = 0; i < pageCount; i++) {
        buffer.write('${3 + i} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n');
      }

      buffer.write('xref\n0 ${3 + pageCount}\n0000000000 65535 f \n');
      for (int i = 1; i < 3 + pageCount; i++) {
        buffer.write('0000000010 00000 n \n');
      }
      buffer.write('trailer\n<< /Size ${3 + pageCount} /Root 1 0 R >>\nstartxref\n500\n%%EOF\n');

      await tempFile.writeAsString(buffer.toString());

      await _importPipeline.importBook(
        sourceFile: tempFile,
        title: title,
        author: 'ReadMesh Community',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess(title))),
        );
      }
    } on DuplicateBookException catch (dupEx) {
      // Friendly Arabic/English dialog, keep SHA-256 protection but don't show stack
      if (mounted) {
        final existing = await _bookRepo.getBookBySha256(dupEx.sha256);
        await _showDuplicateDialog(existing);
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('already exists') || e is DuplicateBookException) {
          // Fallback duplicate handling
          final l10nInner = AppLocalizations.of(context);
          await _showDuplicateDialog(null);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.importFailed}: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showDuplicateDialog(Book? existingBook) async {
    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.duplicateBookTitle),
        content: Text(l10n.duplicateBookMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
          if (existingBook != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfReaderScreen(book: existingBook),
                  ),
                );
              },
              child: Text(l10n.openBookAction),
            ),
        ],
      ),
    );
  }

  /// Deletes a book from SQLite and storage.
  Future<void> _deleteBook(Book book) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteBookConfirmTitle),
        content: Text(l10n.deleteBookConfirmBody(book.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _fileManager.deleteFile(book.filePath);
      await _bookRepo.deleteBook(book.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleted(book.title))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myPdfLibrary),
        actions: [
          if (_isImporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n.importBook,
              onPressed: () => _importSampleBook(),
            ),
        ],
      ),
      body: StreamBuilder<List<Book>>(
        stream: _bookRepo.watchAllBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildBookCard(book);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books_rounded, size: 72, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              l10n.noBooksInLibrary,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.importHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : () => _importSampleBook(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.importSamplePdf),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Center(
                    child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 30),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${book.pageCount} pages • ${StorageUsageReport.formatBytes(book.fileSize)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8)),
                  tooltip: l10n.deleteBook,
                  onPressed: () => _deleteBook(book),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<DeviceProfile>(
              future: _deviceService.getOrCreateCurrentProfile(),
              builder: (context, profileSnap) {
                if (!profileSnap.hasData) return const SizedBox.shrink();
                final deviceId = profileSnap.data!.id;

                return StreamBuilder<ReadingProgress?>(
                  stream: _progressRepo.watchLatestBookProgress(book.id, deviceId),
                  builder: (context, progSnap) {
                    final progress = progSnap.data;
                    final currentPage = progress?.currentPage ?? 1;
                    final totalPages = book.pageCount > 0 ? book.pageCount : 1;
                    final pct = (currentPage / totalPages).clamp(0.0, 1.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              progress != null
                                  ? l10n.pageOf(currentPage, totalPages) + ' (${(pct * 100).toStringAsFixed(0)}%)'
                                  : l10n.notStartedYet,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress != null ? pct : 0.0,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfReaderScreen(book: book),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_stories_rounded, size: 18),
                label: Text(l10n.readNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
