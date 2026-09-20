import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 2 Database Schema & 12 Tables Tests', () {
    test('Verifies all 12 tables exist and can perform CRUD operations', () async {
      final now = DateTime.now().toUtc();

      // 1. device_profile
      await db.into(db.deviceProfileTable).insert(
            DeviceProfileTableCompanion.insert(
              id: 'dev-1',
              displayName: 'Device One',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final profile = await (db.select(db.deviceProfileTable)..where((t) => t.id.equals('dev-1'))).getSingle();
      expect(profile.displayName, equals('Device One'));

      // 2. books (stores only metadata and filePath, NEVER binary!)
      await db.into(db.booksTable).insert(
            BooksTableCompanion.insert(
              id: 'book-1',
              title: 'Clean Code',
              author: 'Robert C. Martin',
              filePath: '/storage/books/book-1.pdf',
              fileSize: 1024500,
              pageCount: 464,
              sha256Hash: 'hash-abc-123',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final book = await (db.select(db.booksTable)..where((t) => t.id.equals('book-1'))).getSingle();
      expect(book.title, equals('Clean Code'));
      expect(book.filePath, equals('/storage/books/book-1.pdf'));

      // 3. sessions
      await db.into(db.sessionsTable).insert(
            SessionsTableCompanion.insert(
              id: 'session-1',
              title: 'Reading Circle',
              hostDeviceId: 'dev-1',
              bookId: 'book-1',
              status: 'active',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final session = await (db.select(db.sessionsTable)..where((t) => t.id.equals('session-1'))).getSingle();
      expect(session.title, equals('Reading Circle'));

      // 4. session_members
      await db.into(db.sessionMembersTable).insert(
            SessionMembersTableCompanion.insert(
              id: 'member-1',
              sessionId: 'session-1',
              deviceId: 'dev-1',
              displayName: 'Device One',
              role: 'host',
              joinedAt: now,
              lastSeenAt: now,
              status: 'active',
            ),
          );
      final member = await (db.select(db.sessionMembersTable)..where((t) => t.id.equals('member-1'))).getSingle();
      expect(member.role, equals('host'));

      // 5. session_events
      await db.into(db.sessionEventsTable).insert(
            SessionEventsTableCompanion.insert(
              id: 'event-1',
              sessionId: 'session-1',
              deviceId: 'dev-1',
              eventType: 'page_change',
              payload: '{"page": 2}',
              sequenceNumber: 1,
              createdAt: now,
            ),
          );
      final event = await (db.select(db.sessionEventsTable)..where((t) => t.id.equals('event-1'))).getSingle();
      expect(event.eventType, equals('page_change'));

      // 6. outbox
      await db.into(db.outboxTable).insert(
            OutboxTableCompanion.insert(
              id: 'outbox-1',
              sessionId: const Value('session-1'),
              messageType: 'sync_event',
              payload: '{"data": "test"}',
              status: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final outbox = await (db.select(db.outboxTable)..where((t) => t.id.equals('outbox-1'))).getSingle();
      expect(outbox.status, equals('pending'));

      // 7. reading_progress
      await db.into(db.readingProgressTable).insert(
            ReadingProgressTableCompanion.insert(
              id: 'prog-1',
              sessionId: 'session-1',
              bookId: 'book-1',
              deviceId: 'dev-1',
              currentPage: 42,
              totalPages: 464,
              percentage: 42 / 464,
              updatedAt: now,
            ),
          );
      final progress = await (db.select(db.readingProgressTable)..where((t) => t.id.equals('prog-1'))).getSingle();
      expect(progress.currentPage, equals(42));

      // 8. participant_reading_time
      await db.into(db.participantReadingTimeTable).insert(
            ParticipantReadingTimeTableCompanion.insert(
              id: 'time-1',
              sessionId: 'session-1',
              deviceId: 'dev-1',
              totalSeconds: const Value(3600),
              lastActiveAt: now,
              updatedAt: now,
            ),
          );
      final time = await (db.select(db.participantReadingTimeTable)..where((t) => t.id.equals('time-1'))).getSingle();
      expect(time.totalSeconds, equals(3600));

      // 9. page_activity
      await db.into(db.pageActivityTable).insert(
            PageActivityTableCompanion.insert(
              id: 'activity-1',
              sessionId: 'session-1',
              bookId: 'book-1',
              pageNumber: 42,
              deviceId: 'dev-1',
              durationSeconds: 120,
              createdAt: now,
            ),
          );
      final activity = await (db.select(db.pageActivityTable)..where((t) => t.id.equals('activity-1'))).getSingle();
      expect(activity.durationSeconds, equals(120));

      // 10. messages
      await db.into(db.messagesTable).insert(
            MessagesTableCompanion.insert(
              id: 'msg-1',
              sessionId: 'session-1',
              senderId: 'dev-1',
              senderName: 'Device One',
              content: 'Welcome to ReadMesh!',
              messageType: 'text',
              createdAt: now,
            ),
          );
      final msg = await (db.select(db.messagesTable)..where((t) => t.id.equals('msg-1'))).getSingle();
      expect(msg.content, equals('Welcome to ReadMesh!'));

      // 11. notes
      await db.into(db.notesTable).insert(
            NotesTableCompanion.insert(
              id: 'note-1',
              bookId: 'book-1',
              pageNumber: 42,
              deviceId: 'dev-1',
              authorName: 'Device One',
              content: 'Interesting paragraph here.',
              color: '#FFEB3B',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final note = await (db.select(db.notesTable)..where((t) => t.id.equals('note-1'))).getSingle();
      expect(note.content, equals('Interesting paragraph here.'));

      // 12. kvs
      await db.into(db.kvsTable).insert(
            KvsTableCompanion.insert(
              key: 'app_theme',
              value: 'light',
              updatedAt: now,
            ),
          );
      final kvs = await (db.select(db.kvsTable)..where((t) => t.key.equals('app_theme'))).getSingle();
      expect(kvs.value, equals('light'));
    });

    test('Foreign key cascade deletes remove child records cleanly', () async {
      final now = DateTime.now().toUtc();

      // Insert book
      await db.into(db.booksTable).insert(
            BooksTableCompanion.insert(
              id: 'book-cas',
              title: 'Cascade Book',
              author: 'Author',
              filePath: '/books/cascade.pdf',
              fileSize: 100,
              pageCount: 10,
              sha256Hash: 'hash-cas',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert note for book
      await db.into(db.notesTable).insert(
            NotesTableCompanion.insert(
              id: 'note-cas',
              bookId: 'book-cas',
              pageNumber: 1,
              deviceId: 'dev-1',
              authorName: 'Author',
              content: 'Cascading note',
              color: '#FFFF00',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert session for book
      await db.into(db.sessionsTable).insert(
            SessionsTableCompanion.insert(
              id: 'session-cas',
              title: 'Cascade Session',
              hostDeviceId: 'dev-1',
              bookId: 'book-cas',
              status: 'active',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert session member
      await db.into(db.sessionMembersTable).insert(
            SessionMembersTableCompanion.insert(
              id: 'mem-cas',
              sessionId: 'session-cas',
              deviceId: 'dev-1',
              displayName: 'User',
              role: 'host',
              joinedAt: now,
              lastSeenAt: now,
              status: 'active',
            ),
          );

      // Verify records exist
      expect((await db.select(db.notesTable).get()).length, equals(1));
      expect((await db.select(db.sessionMembersTable).get()).length, equals(1));

      // Delete the book -> cascades to session and notes!
      await (db.delete(db.booksTable)..where((t) => t.id.equals('book-cas'))).go();

      // All cascading records should now be 0
      expect((await db.select(db.booksTable).get()).isEmpty, isTrue);
      expect((await db.select(db.sessionsTable).get()).isEmpty, isTrue);
      expect((await db.select(db.notesTable).get()).isEmpty, isTrue);
      expect((await db.select(db.sessionMembersTable).get()).isEmpty, isTrue);
    });

    test('Confirms device_profile table contains ONLY id, display_name, created_at, updated_at', () async {
      final columns = await db.customSelect("PRAGMA table_info('device_profile');").get();
      final columnNames = columns.map((r) => r.data['name'] as String).toSet();

      expect(columnNames, equals({'id', 'display_name', 'created_at', 'updated_at'}));
      expect(columnNames.contains('public_key'), isFalse);
    });

    test('Confirms NO binary/BLOB columns in books table (only filePath & metadata)', () async {
      final columns = await db.customSelect("PRAGMA table_info('books');").get();
      final columnNames = columns.map((r) => r.data['name'] as String).toList();
      final columnTypes = {for (var r in columns) r.data['name'] as String: r.data['type'] as String};

      expect(columnNames, contains('file_path'));
      expect(columnNames, contains('file_size'));
      expect(columnNames, contains('sha256_hash'));

      // Check types: NO BLOB column exists in books table
      for (final entry in columnTypes.entries) {
        expect(
          entry.value.toUpperCase(),
          isNot(contains('BLOB')),
          reason: 'Column ${entry.key} in books table must not be BLOB',
        );
      }
    });

    test('Verifies foreign keys are enforced by PRAGMA foreign_keys = ON', () async {
      final enabled = await db.areForeignKeysEnabled();
      expect(enabled, isTrue);
    });
  });
}
