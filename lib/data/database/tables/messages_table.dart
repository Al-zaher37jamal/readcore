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

  @override
  Set<Column> get primaryKey => {id};
}
