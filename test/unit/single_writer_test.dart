import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/database/single_writer_lock.dart';

void main() {
  group('Single-Writer Strategy Tests', () {
    test('Serializes concurrent write operations deterministically', () async {
      final lock = SingleWriterLock();
      final executionOrder = <int>[];

      // Launch 10 concurrent async operations
      final futures = List.generate(10, (index) {
        return lock.synchronized(() async {
          await Future.delayed(const Duration(milliseconds: 5));
          executionOrder.add(index);
          return index;
        });
      });

      final results = await Future.wait(futures);

      expect(results, equals(List.generate(10, (i) => i)));
      expect(executionOrder, equals(List.generate(10, (i) => i)));
    });

    test('Prevents database lock contention under rapid parallel SQLite writes', () async {
      final db = AppDatabase.memory();
      final writeCount = 50;

      // Launch 50 concurrent writes using writeTx
      final futures = List.generate(writeCount, (i) {
        return db.writeTx(() async {
          await db.into(db.kvsTable).insert(
                KvsTableCompanion.insert(
                  key: 'key_$i',
                  value: 'value_$i',
                  updatedAt: DateTime.now(),
                ),
              );
        });
      });

      await Future.wait(futures);

      final totalEntries = (await db.select(db.kvsTable).get()).length;
      expect(totalEntries, equals(writeCount));

      await db.close();
    });
  });
}
