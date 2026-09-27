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

  // Phase 6: Session History and Resumable Local Reading
  // Minimal additional columns for saved/ended lifecycle and resume
  IntColumn get lastPage => integer().nullable()();
  IntColumn get totalPages => integer().nullable()();
  DateTimeColumn get lastActivityAt => dateTime().nullable()();
  TextColumn get sessionType => text().withDefault(const Constant('solo'))();
  BoolColumn get timerEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get statsEnabled => boolean().withDefault(const Constant(false))();

  // Phase 8: a session-wide countdown; the Phase 6 timerEnabled flag and
  // participant_reading_time track elapsed statistics, not this deadline.
  // The checked-in Drift .g.dart predates these columns. Migration v6 adds
  // them to both fresh and existing databases; repository reads use SQL.
  IntColumn get readingDurationMinutes => integer().nullable()();
  DateTimeColumn get readingStartedAt => dateTime().nullable()();
  DateTimeColumn get readingEndsAt => dateTime().nullable()();
  TextColumn get readingConfiguredByLeaderId => text().nullable()();
  TextColumn get readingTimerStatus => text()
      .withDefault(const Constant('not_configured'))();

  @override
  Set<Column> get primaryKey => {id};
}
