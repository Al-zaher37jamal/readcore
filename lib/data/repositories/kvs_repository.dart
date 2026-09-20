import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class KvsRepository {
  Future<void> setString(String key, String value);
  Future<String?> getString(String key);
  Future<bool> deleteKey(String key);
  Future<Map<String, String>> getAll();
  Stream<String?> watchString(String key);
}

class KvsRepositoryImpl implements KvsRepository {
  final AppDatabase _db;

  KvsRepositoryImpl(this._db);

  @override
  Future<void> setString(String key, String value) {
    final now = DateTime.now().toUtc();
    final companion = KvsTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(now),
    );

    return _db.writeTx(() async {
      await _db.into(_db.kvsTable).insertOnConflictUpdate(companion);
    });
  }

  @override
  Future<String?> getString(String key) async {
    final row = await (_db.select(_db.kvsTable)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<bool> deleteKey(String key) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.kvsTable)..where((t) => t.key.equals(key))).go();
      return count > 0;
    });
  }

  @override
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.kvsTable).get();
    return {for (var r in rows) r.key: r.value};
  }

  @override
  Stream<String?> watchString(String key) {
    return (_db.select(_db.kvsTable)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }
}
