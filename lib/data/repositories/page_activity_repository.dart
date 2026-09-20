import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class PageActivityRepository {
  Future<PageActivity> recordActivity({
    required String id,
    required String sessionId,
    required String bookId,
    required int pageNumber,
    required String deviceId,
    required int durationSeconds,
  });

  Future<List<PageActivity>> getActivities(String sessionId, {int? pageNumber});
  Future<int> getTotalTimeOnPage(String sessionId, int pageNumber);
}

class PageActivityRepositoryImpl implements PageActivityRepository {
  final AppDatabase _db;

  PageActivityRepositoryImpl(this._db);

  @override
  Future<PageActivity> recordActivity({
    required String id,
    required String sessionId,
    required String bookId,
    required int pageNumber,
    required String deviceId,
    required int durationSeconds,
  }) async {
    final companion = PageActivityTableCompanion.insert(
      id: id,
      sessionId: sessionId,
      bookId: bookId,
      pageNumber: pageNumber,
      deviceId: deviceId,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now().toUtc(),
    );

    return _db.writeTx(() async {
      await _db.into(_db.pageActivityTable).insert(companion);
      return (await (_db.select(_db.pageActivityTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<List<PageActivity>> getActivities(String sessionId, {int? pageNumber}) {
    var query = _db.select(_db.pageActivityTable)..where((t) => t.sessionId.equals(sessionId));
    if (pageNumber != null) {
      query = query..where((t) => t.pageNumber.equals(pageNumber));
    }
    return (query..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  @override
  Future<int> getTotalTimeOnPage(String sessionId, int pageNumber) async {
    final query = _db.selectOnly(_db.pageActivityTable)
      ..addColumns([_db.pageActivityTable.durationSeconds.sum()])
      ..where(_db.pageActivityTable.sessionId.equals(sessionId) &
          _db.pageActivityTable.pageNumber.equals(pageNumber));

    final result = await query.getSingleOrNull();
    return result?.read(_db.pageActivityTable.durationSeconds.sum()) ?? 0;
  }
}
