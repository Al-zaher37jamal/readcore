import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/books_table.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('ReadingProgress')
class ReadingProgressTable extends Table {
  @override
  String get tableName => 'reading_progress';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get bookId => text().references(BooksTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  IntColumn get currentPage => integer()();
  IntColumn get totalPages => integer()();
  RealColumn get percentage => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
