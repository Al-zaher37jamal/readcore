import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/database/migrations/schema_migrations.dart';

void main() {
  group('Database Migrations Tests', () {
    test('Runs migration strategy and creates v2 indices on upgrade', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Open database and run migration strategy
      await db.customSelect('SELECT 1;').get();

      // Check that indexes created in v2 exist
      final indexRows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='index';").get();
      final indexNames = indexRows.map((r) => r.data['name'] as String).toList();

      expect(indexNames, contains('idx_books_sha256'));
      expect(indexNames, contains('idx_sessions_book_id'));
      expect(indexNames, contains('idx_session_members_session_id'));
      expect(indexNames, contains('idx_session_events_session_seq'));
      expect(indexNames, contains('idx_outbox_status'));
      expect(indexNames, contains('idx_reading_progress_session'));
      expect(indexNames, contains('idx_page_activity_session'));
      expect(indexNames, contains('idx_messages_session'));
      expect(indexNames, contains('idx_notes_book_page'));

      expect(db.schemaVersion, equals(SchemaMigrations.currentSchemaVersion));

      await db.close();
    });
  });
}
