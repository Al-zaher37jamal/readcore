import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('readmesh_wal_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WAL Configuration & Startup Integrity Tests', () {
    test('Configures SQLite journal_mode to WAL for file-backed database', () async {
      final dbFile = File('${tempDir.path}/test_wal.db');
      final db = AppDatabase.forFile(dbFile);

      // Trigger database opening and schema creation
      await db.customSelect('SELECT 1;').get();

      final mode = await db.getJournalMode();
      expect(mode, equals('wal'));

      await db.close();
    });

    test('Startup integrity check passes on healthy database', () async {
      final dbFile = File('${tempDir.path}/test_healthy.db');
      final db = AppDatabase.forFile(dbFile);

      final isHealthy = await db.checkIntegrity();
      expect(isHealthy, isTrue);

      await db.close();
    });

    test('Startup integrity check detects corruption and throws DatabaseCorruptionException', () async {
      final dbFile = File('${tempDir.path}/test_corrupt.db');

      // Create a valid database first
      final db = AppDatabase.forFile(dbFile);
      await db.into(db.kvsTable).insert(
            KvsTableCompanion.insert(
              key: 'key1',
              value: 'val1',
              updatedAt: DateTime.now(),
            ),
          );
      await db.close();

      // Corrupt database pages by overwriting random data into middle of file
      final raf = await dbFile.open(mode: FileMode.append);
      await raf.setPosition(100);
      await raf.writeFrom(List.filled(200, 0xFF));
      await raf.close();

      // Opening the corrupted database with integrity check should throw DatabaseCorruptionException
      final corruptDb = AppDatabase.forFile(dbFile, runIntegrityCheck: true);

      expect(
        () async => await corruptDb.customSelect('SELECT 1;').get(),
        throwsA(isA<DatabaseCorruptionException>()),
      );

      await corruptDb.close();
    });
  });
}
