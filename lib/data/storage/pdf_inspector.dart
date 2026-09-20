import 'dart:convert';
import 'dart:io';
import 'package:readmesh/core/constants/app_constants.dart';
import 'package:readmesh/core/errors/exceptions.dart';

/// Service responsible for validating PDF file structure and inspecting page counts.
class PdfInspector {
  const PdfInspector();

  /// Inspects a PDF file and returns its page count.
  /// Throws [InvalidPdfException] if the file is not a valid PDF.
  /// Throws [PageCountExceededException] if the page count exceeds the maximum limit (~10,000 pages).
  Future<int> inspectPageCount(File file) async {
    if (!await file.exists()) {
      throw const InvalidPdfException('PDF file does not exist.');
    }

    final fileSize = await file.length();
    if (fileSize < 10) {
      throw const InvalidPdfException('File is too small to be a valid PDF.');
    }

    // Step 1: Validate PDF Header (%PDF-)
    final randomAccessFile = await file.open(mode: FileMode.read);
    try {
      final headerBytes = List<int>.filled(1024, 0);
      final bytesRead = await randomAccessFile.readInto(headerBytes, 0, 1024);
      final headerString = latin1.decode(headerBytes.sublist(0, bytesRead));

      if (!headerString.contains('%PDF-')) {
        throw const InvalidPdfException(
          'Invalid PDF format: missing %PDF- header magic bytes.',
        );
      }
    } finally {
      await randomAccessFile.close();
    }

    // Step 2: Determine page count
    final pageCount = await _extractPageCount(file);

    if (pageCount <= 0) {
      throw const InvalidPdfException('Could not find any valid pages in PDF.');
    }

    if (pageCount > AppConstants.maxPdfPages) {
      throw PageCountExceededException(pageCount, AppConstants.maxPdfPages);
    }

    return pageCount;
  }

  /// Extracts page count by reading PDF catalog / pages tree or page objects.
  Future<int> _extractPageCount(File file) async {
    // Strategy A: Scan for /Type /Pages ... /Count N in the PDF stream
    // This is the fastest and most standard way in ISO 32000-1
    final countRegex = RegExp(r'/Type\s*/Pages\b[^>]*?/Count\s+(\d+)|/Count\s+(\d+)[^>]*?/Type\s*/Pages\b');
    final directCountRegex = RegExp(r'/Count\s+(\d+)');
    final pageObjectRegex = RegExp(r'/Type\s*/Page\b(?!s)');

    int highestCount = 0;
    int pageObjectCount = 0;

    // Read the file content as Latin1 (1 byte per char) to preserve binary stream integrity
    final stream = file.openRead();
    final decodedLines = stream.transform(latin1.decoder);

    StringBuffer buffer = StringBuffer();

    await for (final chunk in decodedLines) {
      buffer.write(chunk);
      // Keep a sliding window to search across chunk boundaries
      if (buffer.length > 64 * 1024) {
        final text = buffer.toString();
        // Check for /Pages with /Count
        for (final match in countRegex.allMatches(text)) {
          final countStr = match.group(1) ?? match.group(2);
          if (countStr != null) {
            final c = int.tryParse(countStr) ?? 0;
            if (c > highestCount) highestCount = c;
          }
        }
        // Count /Type /Page
        pageObjectCount += pageObjectRegex.allMatches(text).length;

        // Keep last 1024 chars for sliding window
        final keepFrom = text.length - 1024;
        buffer = StringBuffer(text.substring(keepFrom));
      }
    }

    final remainingText = buffer.toString();
    for (final match in countRegex.allMatches(remainingText)) {
      final countStr = match.group(1) ?? match.group(2);
      if (countStr != null) {
        final c = int.tryParse(countStr) ?? 0;
        if (c > highestCount) highestCount = c;
      }
    }
    // Also check direct /Count if highestCount is still 0
    if (highestCount == 0) {
      for (final match in directCountRegex.allMatches(remainingText)) {
        final countStr = match.group(1);
        if (countStr != null) {
          final c = int.tryParse(countStr) ?? 0;
          if (c > highestCount) highestCount = c;
        }
      }
    }

    pageObjectCount += pageObjectRegex.allMatches(remainingText).length;

    if (highestCount > 0) {
      return highestCount;
    }

    if (pageObjectCount > 0) {
      return pageObjectCount;
    }

    return 0;
  }
}
