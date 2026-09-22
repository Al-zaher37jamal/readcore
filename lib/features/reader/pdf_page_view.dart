import 'dart:io';
import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:pdfx/pdfx.dart';

/// Widget responsible for rendering a REAL PDF document page from local storage
/// using pdfx (Pdfium). Opens the actual file at [filePath] and renders
/// the true PDF content (text/images/layout) for the given [pageNumber].
/// FIXED: Handles pending page jumps for LAN sync (Host 1→2→5→10 Participant follows visibly).
class PdfPageView extends StatefulWidget {
  final String filePath;
  final int pageNumber;
  final int totalPages;
  final String bookTitle;
  final String? author;
  final ValueChanged<int>? onPageChanged;

  const PdfPageView({
    super.key,
    required this.filePath,
    required this.pageNumber,
    required this.totalPages,
    required this.bookTitle,
    this.author,
    this.onPageChanged,
  });

  @override
  State<PdfPageView> createState() => _PdfPageViewState();
}

class _PdfPageViewState extends State<PdfPageView> {
  PdfController? _pdfController;
  bool _isLoading = true;
  String? _errorMessage;
  int _actualPagesCount = 1;
  int? _pendingPageJump;

  @override
  void initState() {
    super.initState();
    _actualPagesCount = widget.totalPages > 0 ? widget.totalPages : 1;
    _pendingPageJump = widget.pageNumber;
    _loadDocument();
  }

  @override
  void didUpdateWidget(covariant PdfPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _pendingPageJump = widget.pageNumber;
      _loadDocument();
      return;
    }
    if (oldWidget.pageNumber != widget.pageNumber) {
      _pendingPageJump = widget.pageNumber;
      _jumpToPage(widget.pageNumber);
    }
    if (oldWidget.totalPages != widget.totalPages) {
      _actualPagesCount = widget.totalPages > 0 ? widget.totalPages : _actualPagesCount;
    }
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        setState(() {
          _errorMessage = 'PDF file not found on device: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      final document = await PdfDocument.openFile(widget.filePath);
      _pdfController?.dispose();

      final initialTarget = (_pendingPageJump ?? widget.pageNumber).clamp(1, document.pagesCount);

      final controller = PdfController(
        document: Future.value(document),
        initialPage: initialTarget,
      );

      if (mounted) {
        setState(() {
          _pdfController = controller;
          _actualPagesCount = document.pagesCount;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pendingPageJump != null) {
            final target = _pendingPageJump!.clamp(1, document.pagesCount);
            _jumpToPage(target);
            _pendingPageJump = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to open PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _jumpToPage(int page) {
    final target = page.clamp(1, _actualPagesCount);
    _pendingPageJump = target;

    if (_pdfController == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pdfController == null) return;
      try {
        _pdfController!.jumpToPage(target);
        _pendingPageJump = null;
      } catch (_) {
        try {
          _pdfController!.animateToPage(target,
              duration: const Duration(milliseconds: 250), curve: Curves.ease);
          _pendingPageJump = null;
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF document...',
                style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon.error(size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDocument,
                icon: AppIcon.refresh(),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('PDF controller not initialized'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return PdfView(
          controller: _pdfController!,
          scrollDirection: Axis.vertical,
          onPageChanged: (page) {
            if (widget.onPageChanged != null) {
              widget.onPageChanged!(page);
            }
          },
          onDocumentLoaded: (document) {
            if (mounted) {
              setState(() {
                _actualPagesCount = document.pagesCount;
              });
              if (_pendingPageJump != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _jumpToPage(_pendingPageJump!);
                    _pendingPageJump = null;
                  }
                });
              }
            }
          },
          onDocumentError: (error) {
            if (mounted) {
              setState(() {
                _errorMessage = 'PDF render error: $error';
              });
            }
          },
          builders: PdfViewBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
            pageLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: (_, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon.error(size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
