import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('SessionEvent')
class SessionEventsTable extends Table {
  @override
  String get tableName => 'session_events';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  TextColumn get eventType => text()();
  TextColumn get payload => text()(); // JSON string
  IntColumn get sequenceNumber => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
