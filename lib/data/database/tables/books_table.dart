import 'package:drift/drift.dart';

@DataClassName('Book')
class BooksTable extends Table {
  @override
  String get tableName => 'books';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  /// Stores relative or absolute file path on local filesystem.
  /// Never store PDF binary data in SQLite!
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();
  IntColumn get pageCount => integer()();
  TextColumn get sha256Hash => text()();
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sha256Hash},
  ];
}
