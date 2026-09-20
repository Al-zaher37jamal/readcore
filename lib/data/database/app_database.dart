import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:readmesh/data/database/connection/connection.dart';
import 'package:readmesh/data/database/migrations/schema_migrations.dart';
import 'package:readmesh/data/database/single_writer_lock.dart';
import 'package:readmesh/data/database/tables/books_table.dart';
import 'package:readmesh/data/database/tables/device_profile_table.dart';
import 'package:readmesh/data/database/tables/kvs_table.dart';
import 'package:readmesh/data/database/tables/messages_table.dart';
import 'package:readmesh/data/database/tables/notes_table.dart';
import 'package:readmesh/data/database/tables/outbox_table.dart';
import 'package:readmesh/data/database/tables/page_activity_table.dart';
import 'package:readmesh/data/database/tables/participant_reading_time_table.dart';
import 'package:readmesh/data/database/tables/reading_progress_table.dart';
import 'package:readmesh/data/database/tables/session_events_table.dart';
import 'package:readmesh/data/database/tables/session_members_table.dart';
import 'package:readmesh/data/database/tables/sessions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    DeviceProfileTable,
    SessionsTable,
    SessionMembersTable,
    SessionEventsTable,
    OutboxTable,
    ReadingProgressTable,
    ParticipantReadingTimeTable,
    PageActivityTable,
    MessagesTable,
    NotesTable,
    BooksTable,
    KvsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  final SingleWriterLock singleWriterLock;
  final bool runIntegrityCheck;

  AppDatabase([QueryExecutor? executor, SingleWriterLock? writerLock, this.runIntegrityCheck = true])
      : singleWriterLock = writerLock ?? SingleWriterLock(),
        super(executor ?? openConnection());

  AppDatabase.memory({SingleWriterLock? writerLock, this.runIntegrityCheck = true})
      : singleWriterLock = writerLock ?? SingleWriterLock(),
        super(NativeDatabase.memory());

  AppDatabase.forFile(File file, {SingleWriterLock? writerLock, this.runIntegrityCheck = true})
      : singleWriterLock = writerLock ?? SingleWriterLock(),
        super(NativeDatabase(file));

  @override
  int get schemaVersion => SchemaMigrations.currentSchemaVersion;

  @override
  MigrationStrategy get migration => SchemaMigrations.createStrategy(
        db: this,
        runIntegrityCheckOnStartup: runIntegrityCheck,
      );

  /// Executes a write operation within the single-writer lock and an atomic transaction.
  Future<T> writeTx<T>(Future<T> Function() action) {
    return singleWriterLock.synchronized(() => transaction(action));
  }

  /// Verifies database integrity using PRAGMA integrity_check.
  Future<bool> checkIntegrity() async {
    try {
      final rows = await customSelect('PRAGMA integrity_check;').get();
      return rows.isNotEmpty && rows.first.data.values.first == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Returns current SQLite journal mode (e.g. 'wal' or 'memory').
  Future<String> getJournalMode() async {
    final rows = await customSelect('PRAGMA journal_mode;').get();
    if (rows.isNotEmpty) {
      return rows.first.data.values.first.toString().toLowerCase();
    }
    return '';
  }

  /// Returns whether foreign key enforcement is active.
  Future<bool> areForeignKeysEnabled() async {
    final rows = await customSelect('PRAGMA foreign_keys;').get();
    if (rows.isNotEmpty) {
      return rows.first.data.values.first == 1;
    }
    return false;
  }
}
