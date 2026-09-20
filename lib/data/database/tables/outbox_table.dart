import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('OutboxEntry')
class OutboxTable extends Table {
  @override
  String get tableName => 'outbox';

  TextColumn get id => text()();
  TextColumn get sessionId => text().nullable().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get messageType => text()();
  TextColumn get payload => text()(); // JSON string
  TextColumn get status => text()(); // 'pending', 'in_flight', 'sent', 'failed'
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
