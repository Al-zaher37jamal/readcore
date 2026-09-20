import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/books_table.dart';

@DataClassName('Session')
class SessionsTable extends Table {
  @override
  String get tableName => 'sessions';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get hostDeviceId => text()();
  TextColumn get bookId => text().references(BooksTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
