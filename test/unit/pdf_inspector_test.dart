import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/storage/pdf_inspector.dart';
import '../test_helpers.dart';

void main() {
  late Directory tempDir;
  const inspector = PdfInspector();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_inspector_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PdfInspector Tests', () {
    test('Accurately inspects page count of valid PDF documents', () async {
      final pdfFile = File('${tempDir.path}/valid_5_pages.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 5);

      final count = await inspector.inspectPageCount(pdfFile);
      expect(count, equals(5));
    });

    test('Rejects non-PDF files missing %PDF- header magic bytes', () async {
      final invalidFile = File('${tempDir.path}/fake.pdf');
      await invalidFile.writeAsString('This is not a PDF file.');

      expect(
        () async => await inspector.inspectPageCount(invalidFile),
        throwsA(isA<InvalidPdfException>()),
      );
    });

    test('Rejects PDF documents exceeding maximum ~10,000 pages limit', () async {
      final largePageFile = File('${tempDir.path}/exceeded_pages.pdf');
      await TestHelpers.createSamplePdfFile(largePageFile, pageCount: 10005);

      expect(
        () async => await inspector.inspectPageCount(largePageFile),
        throwsA(isA<PageCountExceededException>()),
      );
    });
  });
}
