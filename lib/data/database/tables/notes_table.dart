import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/books_table.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

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

  // Phase 6: null session_id keeps existing book-level Phase 2 notes intact.
  TextColumn get sessionId => text().nullable().references(
      SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get noteKind => text().withDefault(const Constant('note'))();
  TextColumn get visibility => text().withDefault(const Constant('personal'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  RealColumn get regionWidth => real().nullable()();
  RealColumn get regionHeight => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
