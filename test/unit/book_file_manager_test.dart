import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';

void main() {
  late Directory tempDir;
  late BookFileManager fileManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_file_mgr_test_');
    fileManager = BookFileManager(tempDir);
    await fileManager.initialize();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BookFileManager Tests', () {
    test('Initializes directories correctly', () async {
      expect(await fileManager.booksDir.exists(), isTrue);
      expect(await fileManager.cacheDir.exists(), isTrue);
      expect(await fileManager.tempDir.exists(), isTrue);
    });

    test('Generates correct paths', () {
      final bookPath = fileManager.getBookFilePath('book123');
      expect(bookPath, endsWith('/books/book123.pdf'));

      final tempPath = fileManager.getTempFilePath('temp123.tmp');
      expect(tempPath, endsWith('/temp/temp123.tmp'));

      final cachePath = fileManager.getCacheFilePath('cache123.bin');
      expect(cachePath, endsWith('/cache/cache123.bin'));
    });

    test('Performs file existence, size, and deletion operations', () async {
      final testFile = File(fileManager.getCacheFilePath('test.txt'));
      await testFile.writeAsString('Hello World');

      expect(await fileManager.fileExists(testFile.path), isTrue);
      expect(await fileManager.getFileSize(testFile.path), equals(11));

      final deleted = await fileManager.deleteFile(testFile.path);
      expect(deleted, isTrue);
      expect(await fileManager.fileExists(testFile.path), isFalse);
    });

    test('Clears temporary directory properly', () async {
      final temp1 = File(fileManager.getTempFilePath('f1.tmp'));
      final temp2 = File(fileManager.getTempFilePath('f2.tmp'));
      await temp1.writeAsString('temp1');
      await temp2.writeAsString('temp2');

      expect((await fileManager.listTempFiles()).length, equals(2));

      final cleanedCount = await fileManager.clearTempDirectory();
      expect(cleanedCount, equals(2));
      expect((await fileManager.listTempFiles()).length, equals(0));
    });
  });
}
