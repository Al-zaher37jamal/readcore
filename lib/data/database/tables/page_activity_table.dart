import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/books_table.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('PageActivity')
class PageActivityTable extends Table {
  @override
  String get tableName => 'page_activity';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get bookId => text().references(BooksTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get deviceId => text()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
