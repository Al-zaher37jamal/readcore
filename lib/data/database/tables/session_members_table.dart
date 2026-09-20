import 'package:drift/drift.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

@DataClassName('SessionMember')
class SessionMembersTable extends Table {
  @override
  String get tableName => 'session_members';

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get deviceId => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()(); // 'host', 'participant'
  DateTimeColumn get joinedAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  TextColumn get status => text()(); // 'active', 'disconnected', 'left'

  @override
  Set<Column> get primaryKey => {id};
}
