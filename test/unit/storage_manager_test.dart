import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/storage_manager.dart';

void main() {
  late Directory tempDir;
  late BookFileManager fileManager;
  late MockDiskSpaceChecker diskSpaceChecker;
  late File customDbFile;
  late StorageManager storageManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_storage_test_');
    fileManager = BookFileManager(tempDir);
    await fileManager.initialize();
    diskSpaceChecker = MockDiskSpaceChecker(500 * 1024 * 1024); // 500 MB

    customDbFile = File('${tempDir.path}/test_app.db');
    await customDbFile.writeAsBytes(List.filled(2048, 0)); // 2 KB db file

    storageManager = StorageManager(
      fileManager: fileManager,
      diskSpaceChecker: diskSpaceChecker,
      customDatabaseFile: customDbFile,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageManager Tests', () {
    test('Calculates and reports storage accurately for Books, Cache, Database, Total, Available', () async {
      // Put a 5 KB file in books
      final bookFile = File('${fileManager.booksDir.path}/sample.pdf');
      await bookFile.writeAsBytes(List.filled(5120, 1));

      // Put a 1 KB file in cache
      final cacheFile = File('${fileManager.cacheDir.path}/cached.bin');
      await cacheFile.writeAsBytes(List.filled(1024, 2));

      final report = await storageManager.getStorageUsage();

      expect(report.books, equals(5120));
      expect(report.cache, equals(1024));
      expect(report.database, equals(2048));
      expect(report.total, equals(5120 + 1024 + 2048));
      expect(report.available, equals(500 * 1024 * 1024));

      // Verify report map contains ONLY Books, Cache, Database, Total, Available
      final map = report.toMap();
      expect(map.keys.toSet(), equals({'books', 'cache', 'database', 'total', 'available'}));
      expect(map.containsKey('audio'), isFalse);
    });

    test('Clears cache directory correctly', () async {
      final cache1 = File('${fileManager.cacheDir.path}/c1.tmp');
      final cache2 = File('${fileManager.cacheDir.path}/c2.tmp');
      await cache1.writeAsString('c1');
      await cache2.writeAsString('c2');

      expect((await fileManager.listCacheFiles()).length, equals(2));

      final cleared = await storageManager.clearCache();
      expect(cleared, equals(2));
      expect((await fileManager.listCacheFiles()).length, equals(0));

      final report = await storageManager.getStorageUsage();
      expect(report.cache, equals(0));
    });
  });
}
