import 'package:drift/drift.dart';

@DataClassName('KvsEntry')
class KvsTable extends Table {
  @override
  String get tableName => 'kvs';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
