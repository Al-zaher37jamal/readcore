import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('Message')
class MessagesTable extends Table {
  @override
  String get tableName => 'messages';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get senderId => text()();
  TextColumn get senderName => text()();
  TextColumn get content => text()();
  TextColumn get messageType => text()(); // 'text', 'system'
  DateTimeColumn get createdAt => dateTime()();

  // Page-specific local text messages reuse the existing sessions/messages FK.
  // The checked-in generated Drift file predates these fields; migrations add
  // missing columns on both new and existing databases until codegen runs.
  IntColumn get pageNumber => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('local'))();

  // Legacy Phase 6 metadata is retained for existing databases and callers.
  TextColumn get voicePath => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get voiceSha256 => text().nullable()();
  IntColumn get voiceBytes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
