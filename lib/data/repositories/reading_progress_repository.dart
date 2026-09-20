import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class ReadingProgressRepository {
  Future<ReadingProgress> updateProgress({
    required String id,
    required String sessionId,
    required String bookId,
    required String deviceId,
    required int currentPage,
    required int totalPages,
  });

  Future<ReadingProgress?> getProgress(String sessionId, String deviceId);
  Future<ReadingProgress?> getLatestBookProgress(String bookId, String deviceId);
  Future<List<ReadingProgress>> getAllSessionProgress(String sessionId);
  Stream<List<ReadingProgress>> watchSessionProgress(String sessionId);
  Stream<ReadingProgress?> watchLatestBookProgress(String bookId, String deviceId);
}

class ReadingProgressRepositoryImpl implements ReadingProgressRepository {
  final AppDatabase _db;

  ReadingProgressRepositoryImpl(this._db);

  @override
  Future<ReadingProgress> updateProgress({
    required String id,
    required String sessionId,
    required String bookId,
    required String deviceId,
    required int currentPage,
    required int totalPages,
  }) async {
    final percentage = totalPages > 0 ? (currentPage / totalPages) : 0.0;
    final now = DateTime.now().toUtc();

    final companion = ReadingProgressTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      bookId: Value(bookId),
      deviceId: Value(deviceId),
      currentPage: Value(currentPage),
      totalPages: Value(totalPages),
      percentage: Value(percentage),
      updatedAt: Value(now),
    );

    return _db.writeTx(() async {
      await _db.into(_db.readingProgressTable).insertOnConflictUpdate(companion);
      return (await (_db.select(_db.readingProgressTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<ReadingProgress?> getProgress(String sessionId, String deviceId) {
    return (_db.select(_db.readingProgressTable)
          ..where((t) => t.sessionId.equals(sessionId) & t.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  @override
  Future<ReadingProgress?> getLatestBookProgress(String bookId, String deviceId) {
    return (_db.select(_db.readingProgressTable)
          ..where((t) => t.bookId.equals(bookId) & t.deviceId.equals(deviceId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<List<ReadingProgress>> getAllSessionProgress(String sessionId) {
    return (_db.select(_db.readingProgressTable)..where((t) => t.sessionId.equals(sessionId))).get();
  }

  @override
  Stream<List<ReadingProgress>> watchSessionProgress(String sessionId) {
    return (_db.select(_db.readingProgressTable)..where((t) => t.sessionId.equals(sessionId))).watch();
  }

  @override
  Stream<ReadingProgress?> watchLatestBookProgress(String bookId, String deviceId) {
    return (_db.select(_db.readingProgressTable)
          ..where((t) => t.bookId.equals(bookId) & t.deviceId.equals(deviceId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }
}
