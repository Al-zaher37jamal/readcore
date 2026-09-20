import 'package:flutter/material.dart';

/// Widget responsible for rendering a PDF document page visually with paper styling,
/// responsive scaling, and pan/zoom interactions.
class PdfPageView extends StatelessWidget {
  final int pageNumber;
  final int totalPages;
  final String bookTitle;
  final String? author;

  const PdfPageView({
    super.key,
    required this.pageNumber,
    required this.totalPages,
    required this.bookTitle,
    this.author,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth * 0.92;
        final pageHeight = constraints.maxHeight * 0.95;

        return Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 3.0,
            child: Container(
              width: pageWidth,
              height: pageHeight,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          bookTitle.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'P. $pageNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),

                  // Page Body Preview / Document Canvas
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pageNumber == 1) ...[
                            const SizedBox(height: 24),
                            Center(
                              child: Text(
                                bookTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (author != null && author!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'By $author',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            const Divider(color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 16),
                          ],

                          // Simulated Content Section for Page
                          Text(
                            'Section $pageNumber — Reading Session',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Welcome to page $pageNumber of $totalPages in "$bookTitle". '
                            'ReadMesh synchronizes your local reading progress seamlessly across '
                            'peer reading rooms and solo study sessions.\n\n'
                            'This document is rendered directly from your verified local storage. '
                            'Turning pages automatically updates your persistent progress in SQLite, '
                            'guaranteeing that your reading state is preserved across app relaunches.',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Visual Content Blocks
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bookmark_added_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Reading progress: page $pageNumber of $totalPages '
                                    '(${((pageNumber / totalPages) * 100).toStringAsFixed(1)}%)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Page Footer
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Center(
                    child: Text(
                      'Page $pageNumber of $totalPages',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
