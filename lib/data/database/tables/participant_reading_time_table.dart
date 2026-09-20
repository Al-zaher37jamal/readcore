import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('ParticipantReadingTime')
class ParticipantReadingTimeTable extends Table {
  @override
  String get tableName => 'participant_reading_time';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  IntColumn get totalSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastActiveAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
