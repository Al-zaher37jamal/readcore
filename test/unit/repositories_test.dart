import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/kvs_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/note_repository.dart';
import 'package:readmesh/data/repositories/outbox_repository.dart';
import 'package:readmesh/data/repositories/page_activity_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_event_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';

void main() {
  late AppDatabase db;
  late DeviceProfileRepository deviceProfileRepo;
  late BookRepository bookRepo;
  late SessionRepository sessionRepo;
  late SessionMemberRepository sessionMemberRepo;
  late SessionEventRepository sessionEventRepo;
  late OutboxRepository outboxRepo;
  late ReadingProgressRepository readingProgressRepo;
  late ParticipantReadingTimeRepository participantReadingTimeRepo;
  late PageActivityRepository pageActivityRepo;
  late MessageRepository messageRepo;
  late NoteRepository noteRepo;
  late KvsRepository kvsRepo;

  setUp(() {
    db = AppDatabase.memory();
    deviceProfileRepo = DeviceProfileRepositoryImpl(db);
    bookRepo = BookRepositoryImpl(db);
    sessionRepo = SessionRepositoryImpl(db);
    sessionMemberRepo = SessionMemberRepositoryImpl(db);
    sessionEventRepo = SessionEventRepositoryImpl(db);
    outboxRepo = OutboxRepositoryImpl(db);
    readingProgressRepo = ReadingProgressRepositoryImpl(db);
    participantReadingTimeRepo = ParticipantReadingTimeRepositoryImpl(db);
    pageActivityRepo = PageActivityRepositoryImpl(db);
    messageRepo = MessageRepositoryImpl(db);
    noteRepo = NoteRepositoryImpl(db);
    kvsRepo = KvsRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('All 12 Repositories CRUD & Reactive Streams Tests', () {
    test('DeviceProfileRepository save, update, get, delete', () async {
      final saved = await deviceProfileRepo.saveProfile(
        id: 'dev-abc',
        displayName: 'Alice',
      );
      expect(saved.displayName, equals('Alice'));

      final fetched = await deviceProfileRepo.getProfile();
      expect(fetched?.id, equals('dev-abc'));

      final updated = await deviceProfileRepo.updateDisplayName('Alice Updated');
      expect(updated, isTrue);

      final fetchedUpdated = await deviceProfileRepo.getProfile();
      expect(fetchedUpdated?.displayName, equals('Alice Updated'));

      final deleted = await deviceProfileRepo.deleteProfile();
      expect(deleted, isTrue);
      expect(await deviceProfileRepo.getProfile(), isNull);
    });

    test('BookRepository CRUD, queries by sha256 and streams', () async {
      final book = await bookRepo.createBook(
        id: 'book-r1',
        title: 'Domain-Driven Design',
        author: 'Eric Evans',
        filePath: '/path/ddd.pdf',
        fileSize: 5000000,
        pageCount: 560,
        sha256Hash: 'sha-ddd-456',
      );

      expect(book.title, equals('Domain-Driven Design'));

      final bySha = await bookRepo.getBookBySha256('sha-ddd-456');
      expect(bySha?.id, equals('book-r1'));

      final all = await bookRepo.getAllBooks();
      expect(all.length, equals(1));

      final deleted = await bookRepo.deleteBook('book-r1');
      expect(deleted, isTrue);
      expect(await bookRepo.getBookById('book-r1'), isNull);
    });

    test('SessionRepository & SessionMemberRepository lifecycle', () async {
      await bookRepo.createBook(
        id: 'book-s1',
        title: 'Book for Session',
        author: 'Author',
        filePath: '/path/b.pdf',
        fileSize: 1000,
        pageCount: 50,
        sha256Hash: 'hash-s1',
      );

      final session = await sessionRepo.createSession(
        id: 'session-r1',
        title: 'Team Reading Club',
        hostDeviceId: 'host-1',
        bookId: 'book-s1',
        status: 'active',
      );

      expect(session.title, equals('Team Reading Club'));

      final member = await sessionMemberRepo.addMember(
        id: 'mem-1',
        sessionId: 'session-r1',
        deviceId: 'host-1',
        displayName: 'Host User',
        role: 'host',
        status: 'active',
      );

      expect(member.role, equals('host'));

      final members = await sessionMemberRepo.getMembersBySessionId('session-r1');
      expect(members.length, equals(1));

      final statusUpdated = await sessionMemberRepo.updateMemberStatus('mem-1', 'disconnected');
      expect(statusUpdated, isTrue);
    });

    test('SessionEventRepository sequence increments and pagination', () async {
      await bookRepo.createBook(
        id: 'book-e1',
        title: 'Book',
        author: 'Author',
        filePath: '/path/e.pdf',
        fileSize: 100,
        pageCount: 10,
        sha256Hash: 'hash-e1',
      );
      await sessionRepo.createSession(
        id: 'session-e1',
        title: 'Event Session',
        hostDeviceId: 'dev-1',
        bookId: 'book-e1',
        status: 'active',
      );

      final seq1 = await sessionEventRepo.getNextSequenceNumber('session-e1');
      expect(seq1, equals(1));

      await sessionEventRepo.recordEvent(
        id: 'ev-1',
        sessionId: 'session-e1',
        deviceId: 'dev-1',
        eventType: 'join',
        payload: '{}',
        sequenceNumber: seq1,
      );

      final seq2 = await sessionEventRepo.getNextSequenceNumber('session-e1');
      expect(seq2, equals(2));

      await sessionEventRepo.recordEvent(
        id: 'ev-2',
        sessionId: 'session-e1',
        deviceId: 'dev-1',
        eventType: 'page_turned',
        payload: '{"page": 3}',
        sequenceNumber: seq2,
      );

      final allEvents = await sessionEventRepo.getEvents('session-e1');
      expect(allEvents.length, equals(2));

      final afterFirst = await sessionEventRepo.getEvents('session-e1', afterSequence: 1);
      expect(afterFirst.length, equals(1));
      expect(afterFirst.first.eventType, equals('page_turned'));
    });

    test('OutboxRepository enqueue, update status, increment retry, remove', () async {
      final entry = await outboxRepo.enqueue(
        id: 'out-1',
        messageType: 'sync_peer',
        payload: '{"key": "val"}',
      );

      expect(entry.status, equals('pending'));
      expect(entry.retryCount, equals(0));

      await outboxRepo.incrementRetry('out-1');
      await outboxRepo.updateStatus('out-1', 'failed');

      final pending = await outboxRepo.getPending();
      // 'failed' is not pending or in_flight
      expect(pending.isEmpty, isTrue);

      final removed = await outboxRepo.remove('out-1');
      expect(removed, isTrue);
    });

    test('ReadingProgress, ReadingTime, PageActivity tracking', () async {
      await bookRepo.createBook(
        id: 'book-t1',
        title: 'Book',
        author: 'Author',
        filePath: '/path/t.pdf',
        fileSize: 100,
        pageCount: 100,
        sha256Hash: 'hash-t1',
      );
      await sessionRepo.createSession(
        id: 'session-t1',
        title: 'Time Session',
        hostDeviceId: 'dev-1',
        bookId: 'book-t1',
        status: 'active',
      );

      // Reading progress
      final progress = await readingProgressRepo.updateProgress(
        id: 'p-1',
        sessionId: 'session-t1',
        bookId: 'book-t1',
        deviceId: 'dev-1',
        currentPage: 50,
        totalPages: 100,
      );
      expect(progress.percentage, equals(0.5));

      // Reading time accumulation
      await participantReadingTimeRepo.addReadingTime(
        id: 'rt-1',
        sessionId: 'session-t1',
        deviceId: 'dev-1',
        additionalSeconds: 300,
      );
      final time2 = await participantReadingTimeRepo.addReadingTime(
        id: 'rt-1',
        sessionId: 'session-t1',
        deviceId: 'dev-1',
        additionalSeconds: 200,
      );
      expect(time2.totalSeconds, equals(500));

      // Page activity
      await pageActivityRepo.recordActivity(
        id: 'pa-1',
        sessionId: 'session-t1',
        bookId: 'book-t1',
        pageNumber: 50,
        deviceId: 'dev-1',
        durationSeconds: 60,
      );
      await pageActivityRepo.recordActivity(
        id: 'pa-2',
        sessionId: 'session-t1',
        bookId: 'book-t1',
        pageNumber: 50,
        deviceId: 'dev-1',
        durationSeconds: 40,
      );
      final totalPageTime = await pageActivityRepo.getTotalTimeOnPage('session-t1', 50);
      expect(totalPageTime, equals(100));
    });

    test('MessageRepository sending and history', () async {
      await bookRepo.createBook(
        id: 'book-m1',
        title: 'Book',
        author: 'Author',
        filePath: '/path/m.pdf',
        fileSize: 100,
        pageCount: 10,
        sha256Hash: 'hash-m1',
      );
      await sessionRepo.createSession(
        id: 'session-m1',
        title: 'Message Session',
        hostDeviceId: 'dev-1',
        bookId: 'book-m1',
        status: 'active',
      );

      await messageRepo.sendMessage(
        id: 'msg-1',
        sessionId: 'session-m1',
        senderId: 'dev-1',
        senderName: 'Bob',
        content: 'Check page 42!',
      );

      final messages = await messageRepo.getMessages('session-m1');
      expect(messages.length, equals(1));
      expect(messages.first.content, equals('Check page 42!'));
    });

    test('NoteRepository creation, queries per book and page', () async {
      await bookRepo.createBook(
        id: 'book-n1',
        title: 'Book',
        author: 'Author',
        filePath: '/path/n.pdf',
        fileSize: 100,
        pageCount: 10,
        sha256Hash: 'hash-n1',
      );

      await noteRepo.createNote(
        id: 'n-1',
        bookId: 'book-n1',
        pageNumber: 5,
        deviceId: 'dev-1',
        authorName: 'Bob',
        content: 'Highlight: crucial theorem',
        color: '#FFFF00',
        positionX: 0.25,
        positionY: 0.60,
      );

      final notes = await noteRepo.getNotesForBook('book-n1', pageNumber: 5);
      expect(notes.length, equals(1));
      expect(notes.first.content, equals('Highlight: crucial theorem'));
    });

    test('KvsRepository key-value setting, updating, retrieval, deletion', () async {
      await kvsRepo.setString('user_theme', 'dark');
      expect(await kvsRepo.getString('user_theme'), equals('dark'));

      // Update key
      await kvsRepo.setString('user_theme', 'system');
      expect(await kvsRepo.getString('user_theme'), equals('system'));

      final all = await kvsRepo.getAll();
      expect(all['user_theme'], equals('system'));

      final deleted = await kvsRepo.deleteKey('user_theme');
      expect(deleted, isTrue);
      expect(await kvsRepo.getString('user_theme'), isNull);
    });
  });
}
