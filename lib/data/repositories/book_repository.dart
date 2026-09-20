import 'package:drift/drift.dart';
import 'package:readmesh/data/database/app_database.dart';

abstract class BookRepository {
  Future<Book> createBook({
    required String id,
    required String title,
    required String author,
    required String filePath,
    required int fileSize,
    required int pageCount,
    required String sha256Hash,
    String? coverPath,
  });

  Future<Book?> getBookById(String id);
  Future<Book?> getBookBySha256(String sha256Hash);
  Future<List<Book>> getAllBooks();
  Stream<List<Book>> watchAllBooks();
  Stream<Book?> watchBookById(String id);
  Future<bool> updateBook(Book book);
  Future<bool> deleteBook(String id);
}

class BookRepositoryImpl implements BookRepository {
  final AppDatabase _db;

  BookRepositoryImpl(this._db);

  @override
  Future<Book> createBook({
    required String id,
    required String title,
    required String author,
    required String filePath,
    required int fileSize,
    required int pageCount,
    required String sha256Hash,
    String? coverPath,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = BooksTableCompanion.insert(
      id: id,
      title: title,
      author: author,
      filePath: filePath,
      fileSize: fileSize,
      pageCount: pageCount,
      sha256Hash: sha256Hash,
      coverPath: Value(coverPath),
      createdAt: now,
      updatedAt: now,
    );

    return _db.writeTx(() async {
      await _db.into(_db.booksTable).insert(companion);
      return (await (_db.select(_db.booksTable)..where((t) => t.id.equals(id))).getSingle());
    });
  }

  @override
  Future<Book?> getBookById(String id) {
    return (_db.select(_db.booksTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<Book?> getBookBySha256(String sha256Hash) {
    return (_db.select(_db.booksTable)..where((t) => t.sha256Hash.equals(sha256Hash))).getSingleOrNull();
  }

  @override
  Future<List<Book>> getAllBooks() {
    return (_db.select(_db.booksTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  @override
  Stream<List<Book>> watchAllBooks() {
    return (_db.select(_db.booksTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  @override
  Stream<Book?> watchBookById(String id) {
    return (_db.select(_db.booksTable)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  @override
  Future<bool> updateBook(Book book) {
    return _db.writeTx(() async {
      final updated = await _db.update(_db.booksTable).replace(
            book.copyWith(updatedAt: DateTime.now().toUtc()),
          );
      return updated;
    });
  }

  @override
  Future<bool> deleteBook(String id) {
    return _db.writeTx(() async {
      final count = await (_db.delete(_db.booksTable)..where((t) => t.id.equals(id))).go();
      return count > 0;
    });
  }
}
