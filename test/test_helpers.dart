import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TestHelpers {
  /// Generates a valid minimal PDF byte array with the requested [pageCount].
  static Uint8List createSamplePdfBytes({int pageCount = 1, String text = 'ReadMesh Test'}) {
    final buffer = StringBuffer();
    buffer.write('%PDF-1.4\n');

    // 1: Catalog
    buffer.write('1 0 obj\n');
    buffer.write('<< /Type /Catalog /Pages 2 0 R >>\n');
    buffer.write('endobj\n');

    // Build kids list
    final kids = <String>[];
    for (int i = 0; i < pageCount; i++) {
      kids.add('${3 + i} 0 R');
    }

    // 2: Pages
    buffer.write('2 0 obj\n');
    buffer.write('<< /Type /Pages /Kids [${kids.join(' ')}] /Count $pageCount >>\n');
    buffer.write('endobj\n');

    // Page objects
    for (int i = 0; i < pageCount; i++) {
      buffer.write('${3 + i} 0 obj\n');
      buffer.write('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\n');
      buffer.write('endobj\n');
    }

    // Trailer
    buffer.write('xref\n');
    buffer.write('0 ${3 + pageCount}\n');
    buffer.write('0000000000 65535 f \n');
    for (int i = 1; i < 3 + pageCount; i++) {
      buffer.write('0000000010 00000 n \n');
    }
    buffer.write('trailer\n');
    buffer.write('<< /Size ${3 + pageCount} /Root 1 0 R >>\n');
    buffer.write('startxref\n');
    buffer.write('500\n');
    buffer.write('%%EOF\n');

    return Uint8List.fromList(latin1.encode(buffer.toString()));
  }

  /// Writes a sample PDF to [file] with specified [pageCount].
  static Future<File> createSamplePdfFile(File file, {int pageCount = 1}) async {
    final bytes = createSamplePdfBytes(pageCount: pageCount);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Creates a sparse file exceeding 300 MB limit with a valid %PDF- header.
  static Future<File> createOversizedPdfFile(File file, {int sizeBytes = 301 * 1024 * 1024}) async {
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeString('%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n');
      await raf.truncate(sizeBytes);
    } finally {
      await raf.close();
    }
    return file;
  }
}
