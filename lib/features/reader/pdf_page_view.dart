import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:pdfx/pdfx.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';

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
  final List<SessionAnnotation> highlights;
  final bool highlightMode;
  final ValueChanged<Rect>? onHighlightSelected;

  const PdfPageView({
    super.key,
    required this.filePath,
    required this.pageNumber,
    required this.totalPages,
    required this.bookTitle,
    this.author,
    this.onPageChanged,
    this.highlights = const [],
    this.highlightMode = false,
    this.onHighlightSelected,
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
  PdfDocument? _document;
  final Map<int, double> _pageAspectRatios = {};
  final Set<int> _pageAspectsLoading = {};
  Offset? _dragStart;
  Offset? _dragEnd;

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
    if (oldWidget.totalPages != widget.totalPages) {
      _actualPagesCount = widget.totalPages > 0 ? widget.totalPages : _actualPagesCount;
    }
    if (oldWidget.pageNumber != widget.pageNumber) {
      _dragStart = null;
      _dragEnd = null;
      _pendingPageJump = widget.pageNumber;
      final document = _document;
      if (document != null) _loadPageAspect(document, widget.pageNumber);
      _jumpToPage(widget.pageNumber);
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
      _document = document;
      _pageAspectRatios.clear();
      _pageAspectsLoading.clear();

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
        _loadPageAspect(document, initialTarget);

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

  Future<void> _loadPageAspect(PdfDocument document, int pageNumber,
      {int attempt = 0}) async {
    if (!identical(document, _document) || pageNumber < 1 ||
        pageNumber > document.pagesCount ||
        _pageAspectRatios.containsKey(pageNumber) ||
        !_pageAspectsLoading.add(pageNumber)) return;
    var retry = false;
    try {
      final page = await document.getPage(pageNumber);
      try {
        final ratio = page.width / page.height;
        if (mounted && identical(document, _document) &&
            ratio.isFinite && ratio > 0) {
          setState(() => _pageAspectRatios[pageNumber] = ratio);
        }
      } finally {
        await page.close();
      }
    } catch (_) {
      // pdfx may be rendering this page at the same instant. Defer a small
      // bounded retry; never paint a guessed PDF page size on failed reads.
      retry = attempt < 3;
    } finally {
      _pageAspectsLoading.remove(pageNumber);
    }
    if (retry && mounted && identical(document, _document)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) await _loadPageAspect(document, pageNumber, attempt: attempt + 1);
    }
  }

  Rect? _containedPageRect(Size size) {
    final ratio = _pageAspectRatios[widget.pageNumber];
    if (ratio == null || size.width <= 0 || size.height <= 0) return null;
    // pdfx's PhotoViewGallery default uses a centered, contained page image.
    final width = math.min(size.width, size.height * ratio);
    final height = width / ratio;
    return Rect.fromLTWH((size.width - width) / 2,
        (size.height - height) / 2, width, height);
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
        ),
      );
    }

    if (_pdfController == null) {
      return const Center(child: Text('PDF controller not initialized'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageRect = _containedPageRect(
            Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(children: [
          Positioned.fill(child: PdfView(
            controller: _pdfController!,
            scrollDirection: Axis.vertical,
            onPageChanged: (page) {
              _loadPageAspect(_document!, page);
              widget.onPageChanged?.call(page);
            },
            onDocumentLoaded: (document) {
              if (mounted) {
                setState(() => _actualPagesCount = document.pagesCount);
                if (_pendingPageJump != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _pendingPageJump != null) {
                      _jumpToPage(_pendingPageJump!);
                      _pendingPageJump = null;
                    }
                  });
                }
              }
            },
            onDocumentError: (error) {
              if (mounted) setState(() => _errorMessage = 'PDF render error: $error');
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AppIcon.error(size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $error', textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                    ]),
                  ),
                ),
              ),
            ),
          )),
          // Draw only inside pdfx's centered, contained PDF page. Normalized
          // document coordinates remain meaningful on differently sized phones.
          if (pageRect != null)
            Positioned.fromRect(rect: pageRect,
              child: IgnorePointer(child: CustomPaint(
                painter: _HighlightPainter(widget.highlights, widget.pageNumber),
              ))),
          if (pageRect != null && widget.highlightMode &&
              widget.onHighlightSelected != null)
            Positioned.fromRect(rect: pageRect, child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => setState(() {
                _dragStart = details.localPosition;
                _dragEnd = details.localPosition;
              }),
              onPanUpdate: (details) => setState(() => _dragEnd = details.localPosition),
              onPanEnd: (_) {
                final start = _dragStart;
                final end = _dragEnd;
                setState(() { _dragStart = null; _dragEnd = null; });
                if (start == null || end == null) return;
                final left = (start.dx < end.dx ? start.dx : end.dx)
                    .clamp(0.0, pageRect.width) / pageRect.width;
                final right = (start.dx > end.dx ? start.dx : end.dx)
                    .clamp(0.0, pageRect.width) / pageRect.width;
                final top = (start.dy < end.dy ? start.dy : end.dy)
                    .clamp(0.0, pageRect.height) / pageRect.height;
                final bottom = (start.dy > end.dy ? start.dy : end.dy)
                    .clamp(0.0, pageRect.height) / pageRect.height;
                if (right - left >= 0.015 && bottom - top >= 0.005) {
                  widget.onHighlightSelected!(Rect.fromLTRB(left, top, right, bottom));
                }
              },
              child: CustomPaint(painter: _HighlightDragPainter(_dragStart, _dragEnd),
                  child: const SizedBox.expand()),
            )),
        ]);
      },
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final List<SessionAnnotation> marks;
  final int page;
  _HighlightPainter(this.marks, this.page);

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      if (mark.kind != 'highlight' || mark.pageNumber != page ||
          mark.x == null || mark.y == null || mark.width == null ||
          mark.height == null) continue;
      final color = Color(int.parse('FF${mark.color.substring(1)}', radix: 16));
      canvas.drawRect(Rect.fromLTWH(mark.x! * size.width,
          mark.y! * size.height, mark.width! * size.width,
          mark.height! * size.height), Paint()..color = color.withOpacity(0.42));
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) =>
      oldDelegate.marks != marks || oldDelegate.page != page;
}

class _HighlightDragPainter extends CustomPainter {
  final Offset? start, end;
  _HighlightDragPainter(this.start, this.end);
  @override
  void paint(Canvas canvas, Size size) {
    if (start == null || end == null) return;
    canvas.drawRect(Rect.fromPoints(start!, end!),
        Paint()..color = const Color(0x77FFD54F));
  }
  @override
  bool shouldRepaint(covariant _HighlightDragPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
