import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class DeviceProfileRepository {
  Future<DeviceProfile?> getProfile();
  Stream<DeviceProfile?> watchProfile();
  Future<DeviceProfile> saveProfile({
    required String id,
    required String displayName,
  });
  Future<bool> updateDisplayName(String displayName);
  Future<bool> deleteProfile();
}

class DeviceProfileRepositoryImpl implements DeviceProfileRepository {
  final AppDatabase _db;

  DeviceProfileRepositoryImpl(this._db);

  @override
  Future<DeviceProfile?> getProfile() {
    return (_db.select(_db.deviceProfileTable)..limit(1)).getSingleOrNull();
  }

  @override
  Stream<DeviceProfile?> watchProfile() {
    return (_db.select(_db.deviceProfileTable)..limit(1)).watchSingleOrNull();
  }

  @override
  Future<DeviceProfile> saveProfile({
    required String id,
    required String displayName,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = DeviceProfileTableCompanion(
      id: Value(id),
      displayName: Value(displayName),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    return _db.writeTx(() async {
      await _db.into(_db.deviceProfileTable).insertOnConflictUpdate(companion);
      return (await (_db.select(_db.deviceProfileTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<bool> updateDisplayName(String displayName) async {
    return _db.writeTx(() async {
      final profile = await getProfile();
      if (profile == null) return false;
      final updated = await _db.update(_db.deviceProfileTable).replace(
            profile.copyWith(
              displayName: displayName,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      return updated;
    });
  }

  @override
  Future<bool> deleteProfile() {
    return _db.writeTx(() async {
      final count = await _db.delete(_db.deviceProfileTable).go();
      return count > 0;
    });
  }
}
