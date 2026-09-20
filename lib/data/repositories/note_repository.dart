import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class NoteRepository {
  Future<Note> createNote({
    required String id,
    required String bookId,
    required int pageNumber,
    required String deviceId,
    required String authorName,
    required String content,
    required String color,
    double? positionX,
    double? positionY,
  });

  Future<List<Note>> getNotesForBook(String bookId, {int? pageNumber});
  Stream<List<Note>> watchNotesForBook(String bookId);
  Future<bool> updateNote(Note note);
  Future<bool> deleteNote(String id);
}

class NoteRepositoryImpl implements NoteRepository {
  final AppDatabase _db;

  NoteRepositoryImpl(this._db);

  @override
  Future<Note> createNote({
    required String id,
    required String bookId,
    required int pageNumber,
    required String deviceId,
    required String authorName,
    required String content,
    required String color,
    double? positionX,
    double? positionY,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = NotesTableCompanion.insert(
      id: id,
      bookId: bookId,
      pageNumber: pageNumber,
      deviceId: deviceId,
      authorName: authorName,
      content: content,
      color: color,
      positionX: Value(positionX),
      positionY: Value(positionY),
      createdAt: now,
      updatedAt: now,
    );

    return _db.writeTx(() async {
      await _db.into(_db.notesTable).insert(companion);
      return (await (_db.select(_db.notesTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<List<Note>> getNotesForBook(String bookId, {int? pageNumber}) {
    var query = _db.select(_db.notesTable)..where((t) => t.bookId.equals(bookId));
    if (pageNumber != null) {
      query = query..where((t) => t.pageNumber.equals(pageNumber));
    }
    return (query..orderBy([(t) => OrderingTerm.asc(t.pageNumber), (t) => OrderingTerm.asc(t.createdAt)])).get();
  }

  @override
  Stream<List<Note>> watchNotesForBook(String bookId) {
    return (_db.select(_db.notesTable)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.asc(t.pageNumber), (t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  @override
  Future<bool> updateNote(Note note) {
    return _db.writeTx(() async {
      final updated = await _db.update(_db.notesTable).replace(
            note.copyWith(updatedAt: DateTime.now().toUtc()),
          );
      return updated;
    });
  }

  @override
  Future<bool> deleteNote(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.notesTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }
}
