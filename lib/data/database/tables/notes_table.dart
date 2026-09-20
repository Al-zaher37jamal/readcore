import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/books_table.dart';

@DataClassName('Note')
class NotesTable extends Table {
  @override
  String get tableName => 'notes';

  TextColumn get id => text()();
  TextColumn get bookId => text().references(BooksTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get deviceId => text()();
  TextColumn get authorName => text()();
  TextColumn get content => text()();
  TextColumn get color => text()();
  RealColumn get positionX => real().nullable()();
  RealColumn get positionY => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
