import 'package:drift/drift.dart';

@DataClassName('DeviceProfile')
class DeviceProfileTable extends Table {
  @override
  String get tableName => 'device_profile';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
