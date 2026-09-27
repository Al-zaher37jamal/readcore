import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/note_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late BookRepository books;
  late SessionRepository sessions;
  late SessionContentRepository content;
  late SessionVoiceStore voices;
  late SessionContentSync sync;
  late ParticipantReadingTimeRepository times;
  const sessionId = 'RM-CONTENT-1';
  const bookId = 'book-content';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase6_content_');
    db = AppDatabase.memory();
    books = BookRepositoryImpl(db);
    sessions = SessionRepositoryImpl(db);
    content = SessionContentRepository(db);
    voices = SessionVoiceStore(root);
    times = ParticipantReadingTimeRepositoryImpl(db);
    await books.createBook(id: bookId, title: 'Pages', author: 'Author',
        filePath: '${root.path}/book.pdf', fileSize: 100,
        pageCount: 20, sha256Hash: 'content-hash');
    await sessions.createSession(id: sessionId, title: 'Room',
        hostDeviceId: 'alice', bookId: bookId, status: 'active');
    sync = SessionContentSync(sessionId: sessionId, bookId: bookId,
        deviceId: 'alice', displayName: 'Alice', totalPages: 20,
        repository: content, voiceStore: voices);
    sync.start();
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  test('v4 extends existing tables, retains book-level schema, and scopes private notes', () async {
    final noteColumns = (await db.customSelect('PRAGMA table_info(notes)').get())
        .map((row) => row.data['name']).toSet();
    final messageColumns = (await db.customSelect('PRAGMA table_info(messages)').get())
        .map((row) => row.data['name']).toSet();
    expect(noteColumns, containsAll(['session_id', 'note_kind', 'visibility',
        'is_pinned', 'region_width', 'region_height']));
    expect(messageColumns, containsAll(['page_number', 'voice_path',
        'duration_ms', 'voice_sha256', 'voice_bytes']));
    await NoteRepositoryImpl(db).createNote(id: 'old-book-note',
        bookId: bookId, pageNumber: 5, deviceId: 'alice',
        authorName: 'Alice', content: 'Older book note', color: '#FFF59D');
    expect((await db.customSelect('SELECT session_id FROM notes WHERE id = ?',
      variables: [Variable.withString('old-book-note')]).getSingle())
      .data['session_id'], isNull);
    final privateNote = await sync.addNote(5, 'Only Alice', shared: false);
    expect(privateNote.visibility, 'personal');
    expect((await content.watchAnnotations(sessionId, 5, 'alice').first).single.id,
        privateNote.id);
    expect(await content.watchAnnotations(sessionId, 5, 'bob').first, isEmpty);
    expect(await content.watchAnnotations(sessionId, 6, 'alice').first, isEmpty);
    expect(await content.sharedAnnotations(sessionId), isEmpty);

    final shared = await sync.addNote(5, 'Shared across devices', shared: true);
    expect((await content.watchAnnotations(sessionId, 5, 'bob').first).single.id,
        shared.id);
    await sync.setPinned(privateNote, true);
    final notes = await content.watchAnnotations(sessionId, 5, 'alice').first;
    expect(notes.first.id, privateNote.id);
    expect(notes.first.isPinned, isTrue);
    expect((await content.watchAnnotations(sessionId, 5, 'bob').first).single.isPinned,
        isFalse);
    await expectLater(sync.setPinned(shared, true), completes);
    expect((await content.watchAnnotations(sessionId, 5, 'bob').first).single.isPinned,
        isTrue);
    final forged = SessionAnnotation(id: shared.id, sessionId: sessionId,
        bookId: bookId, pageNumber: 5, authorId: 'bob', authorName: 'Bob',
        content: 'Overwritten', color: '#FFF59D', kind: 'note',
        visibility: 'shared', isPinned: false,
        createdAt: DateTime.now().toUtc(), updatedAt: DateTime.now().toUtc());
    await expectLater(content.saveAnnotation(forged), throwsFormatException);
    expect((await content.watchAnnotations(sessionId, 5, 'bob').first)
        .single.content, 'Shared across devices');
  });

  test('normalized highlight persists per page, shared filter and validation', () async {
    final mark = await sync.addHighlight(8, 0.12, 0.28, 0.30, 0.11,
        shared: false, color: '#80DEEA');
    final own = (await content.watchAnnotations(sessionId, 8,
        'alice', kind: 'highlight').first).single;
    expect(own.id, mark.id);
    expect(own.x, closeTo(0.12, 0.001));
    expect(own.height, closeTo(0.11, 0.001));
    expect(own.color, '#80DEEA');
    expect(await content.watchAnnotations(sessionId, 8,
        'bob', kind: 'highlight').first, isEmpty);
    final shared = await sync.addHighlight(9, 0.4, 0.1, 0.2, 0.1,
        shared: true);
    expect((await content.watchAnnotations(sessionId, 9,
        'bob', kind: 'highlight').first).single.id, shared.id);
    expect(await content.watchAnnotations(sessionId, 8,
        'bob', kind: 'highlight').first, isEmpty);
    await expectLater(sync.addHighlight(10, 0.95, 0.1, 0.2, 0.1,
        shared: true), throwsFormatException);
    await expectLater(sync.addNote(11, '   ', shared: true),
        throwsFormatException);
  });

  test('page-scoped Unicode text, local voice metadata, and no paths on wire', () async {
    final message = await sync.sendText(11, 'مرحبا 👍 hello');
    expect(message.content, 'مرحبا 👍 hello');
    expect((await content.watchDiscussion(sessionId, 11).first).single.content,
        'مرحبا 👍 hello');
    expect(await content.watchDiscussion(sessionId, 10).first, isEmpty);
    final file = await voices.fileFor(sessionId, 'voice_sample-1');
    final bytes = Uint8List.fromList(List<int>.generate(900, (i) => i % 256));
    await file.writeAsBytes(bytes);
    final voice = await sync.sendVoice(11, file, 1200,
        messageId: 'voice_sample-1');
    expect(voice.voicePath, file.path);
    expect(voice.voiceBytes, bytes.length);
    expect(voice.voiceSha256, sha256.convert(bytes).toString());
    expect(voice.toWire().containsKey('voicePath'), isFalse);
    expect(voice.toWire().toString().contains(root.path), isFalse);
    final restored = await content.getDiscussionById(voice.id);
    expect(restored?.voicePath, file.path);
    expect((await content.watchDiscussion(sessionId, 11).first).length, 2);
    await expectLater(sync.sendVoice(11, File('${root.path}/outside.m4a'), 1200,
        messageId: 'voice_sample-1'), throwsFormatException);
  });

  test('voice bytes are verified and kept in private files rather than SQLite BLOBs', () async {
    const id = 'voice_received';
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final hash = sha256.convert(bytes).toString();
    final file = await voices.saveVerified(sessionId, id, bytes, hash);
    expect(await file.readAsBytes(), bytes);
    expect((await voices.inspect(file)).sha256, hash);
    await expectLater(voices.saveVerified(sessionId, id,
        Uint8List.fromList([7, 8]), hash), throwsFormatException);
    expect(await file.readAsBytes(), bytes);
    expect(file.path, contains('readmesh_voice'));
    expect(file.path, isNot(contains('/$sessionId/')));
    await expectLater(voices.fileFor(sessionId, '../escape'),
        throwsFormatException);
    await expectLater(voices.inspect(await voices.fileFor(sessionId, 'missing')),
        throwsA(isA<FileSystemException>()));
  });

  test('cumulative per-person reading time is durable, monotonic and independent', () async {
    await times.addReadingTime(id: 'alice-time', sessionId: sessionId,
        deviceId: 'alice', additionalSeconds: 15);
    await times.addReadingTime(id: 'new-id-ignored', sessionId: sessionId,
        deviceId: 'alice', additionalSeconds: 8);
    await times.setTimeAtLeast(id: 'bob-time', sessionId: sessionId,
        deviceId: 'bob', totalSeconds: 40);
    await times.setTimeAtLeast(id: 'new-id-ignored', sessionId: sessionId,
        deviceId: 'bob', totalSeconds: 20);
    expect((await times.getTime(sessionId, 'alice'))!.totalSeconds, 23);
    expect((await times.getTime(sessionId, 'bob'))!.totalSeconds, 40);
    expect((await times.getSessionTimes(sessionId)).length, 2);
    await times.setTimeAtLeast(id: 'bob-time', sessionId: sessionId,
        deviceId: 'bob', totalSeconds: 55);
    expect((await times.getTime(sessionId, 'bob'))!.totalSeconds, 55);
    await expectLater(times.addReadingTime(id: 'invalid', sessionId: sessionId,
        deviceId: 'alice', additionalSeconds: -1), throwsArgumentError);
  });

  test('cold launch recovers active/paused/created as Saved, never Ended', () async {
    final members = SessionMemberRepositoryImpl(db);
    await members.addMember(id: 'alice-member', sessionId: sessionId,
        deviceId: 'alice', displayName: 'Alice', role: 'host', status: 'active');
    await sessions.createSession(id: 'RM-PAUSED', title: 'Paused',
        hostDeviceId: 'alice', bookId: bookId, status: 'paused');
    await sessions.createSession(id: 'RM-CREATED', title: 'Created',
        hostDeviceId: 'alice', bookId: bookId, status: 'created');
    await sessions.createSession(id: 'RM-ENDED', title: 'Ended',
        hostDeviceId: 'alice', bookId: bookId, status: 'ended');
    await sessions.updateSessionFlags(sessionId, timerEnabled: true,
        statsEnabled: false);
    await sessions.updateSessionLastPage(sessionId, 12, 20);
    await sync.addNote(12, 'Durable when killed', shared: false);
    expect(await sessions.recoverInterruptedSessions(), 3);
    expect((await sessions.getSessionById(sessionId))!.status, 'saved');
    expect((await sessions.getSessionById('RM-PAUSED'))!.status, 'saved');
    expect((await sessions.getSessionById('RM-CREATED'))!.status, 'saved');
    expect((await sessions.getSessionById('RM-ENDED'))!.status, 'ended');
    expect((await members.getMember(sessionId, 'alice'))!.status, 'disconnected');
    expect((await sessions.getSessionFlags(sessionId))!['timerEnabled'], isTrue);
    expect((await sessions.getSessionFlags(sessionId))!['statsEnabled'], isFalse);
    expect((await content.watchAnnotations(sessionId, 12, 'alice').first)
        .single.content, 'Durable when killed');
    expect(await sessions.recoverInterruptedSessions(), 0);
    expect(await sessions.updateSessionStatus(sessionId, 'active'), isTrue);
    expect((await sessions.getSessionById(sessionId))!.status, 'active');
  });

  test('history deletion cascades annotations, discussion, times, not PDF/book', () async {
    final pdf = File('${root.path}/book.pdf');
    await pdf.writeAsBytes([37, 80, 68, 70]);
    await NoteRepositoryImpl(db).createNote(id: 'legacy-note', bookId: bookId,
        pageNumber: 2, deviceId: 'alice', authorName: 'Alice',
        content: 'Older standalone book note', color: '#FFF59D');
    await sync.addNote(2, 'Keep until deletion', shared: false);
    await sync.sendText(2, 'Delete with history');
    await times.addReadingTime(id: 'time-a', sessionId: sessionId,
        deviceId: 'alice', additionalSeconds: 6);
    final file = await voices.fileFor(sessionId, 'recording');
    await file.writeAsBytes([1, 2, 3]);
    expect(await sessions.deleteSessionHistoryOnly(sessionId), isFalse,
        reason: 'An active live session is not history');
    expect(await sessions.saveAndLeaveSession(sessionId), isTrue);
    expect(await sessions.deleteSessionHistoryOnly(sessionId), isTrue);
    await voices.deleteSessionFiles(sessionId);
    expect(await content.watchAnnotations(sessionId, 2, 'alice').first, isEmpty);
    expect(await content.watchDiscussion(sessionId, 2).first, isEmpty);
    expect(await times.getSessionTimes(sessionId), isEmpty);
    expect(await file.exists(), isFalse);
    expect(await pdf.exists(), isTrue);
    expect(await books.getBookById(bookId), isNotNull);
    expect((await NoteRepositoryImpl(db).getNotesForBook(bookId))
        .any((note) => note.id == 'legacy-note'), isTrue);
  });

  test('file-backed active session becomes Saved after a simulated force-close', () async {
    final file = File('${root.path}/interrupted.sqlite');
    final first = AppDatabase.forFile(file);
    await BookRepositoryImpl(first).createBook(id: 'interrupted-book',
        title: 'PDF', author: 'A', filePath: '${root.path}/other.pdf',
        fileSize: 101, pageCount: 20, sha256Hash: 'interrupted-hash');
    await SessionRepositoryImpl(first).createSession(id: 'RM-INTERRUPTED',
        title: 'Group', hostDeviceId: 'alice',
        bookId: 'interrupted-book', status: 'active');
    await SessionRepositoryImpl(first).updateSessionLastPage('RM-INTERRUPTED',
        10, 20);
    await SessionContentRepository(first).saveAnnotation(SessionAnnotation(
      id: 'note_restart', sessionId: 'RM-INTERRUPTED',
      bookId: 'interrupted-book', pageNumber: 10, authorId: 'alice',
      authorName: 'Alice', content: 'Stay after restart', color: '#FFF59D',
      kind: 'note', visibility: 'personal', isPinned: true,
      createdAt: DateTime.now().toUtc(), updatedAt: DateTime.now().toUtc(),
    ));
    await first.close(); // no Save/End, simulates process loss
    final reopened = AppDatabase.forFile(file);
    try {
      final repo = SessionRepositoryImpl(reopened);
      expect(await repo.recoverInterruptedSessions(), 1);
      expect((await repo.getSessionById('RM-INTERRUPTED'))!.status, 'saved');
      expect((await reopened.customSelect('SELECT last_page FROM sessions '
          "WHERE id = 'RM-INTERRUPTED'").getSingle()).data['last_page'], 10);
      expect((await SessionContentRepository(reopened).watchAnnotations(
          'RM-INTERRUPTED', 10, 'alice').first).single.isPinned, isTrue);
      expect(await repo.updateSessionStatus('RM-INTERRUPTED', 'active'), isTrue);
    } finally {
      await reopened.close();
    }
  });

  test('file-backed SQLite reopens after process-like close with the same IDs', () async {
    final disk = AppDatabase.forFile(File('${root.path}/reopen.sqlite'));
    final diskBooks = BookRepositoryImpl(disk);
    final diskSessions = SessionRepositoryImpl(disk);
    final diskContent = SessionContentRepository(disk);
    final diskTimes = ParticipantReadingTimeRepositoryImpl(disk);
    try {
      await diskBooks.createBook(id: 'disk-book', title: 'Disk PDF', author: 'A',
          filePath: '${root.path}/disk.pdf', fileSize: 100,
          pageCount: 6, sha256Hash: 'disk-hash');
      await diskSessions.createSession(id: 'solo_disk-book', title: 'Solo',
          hostDeviceId: 'alice', bookId: 'disk-book', status: 'active');
      final diskSync = SessionContentSync(sessionId: 'solo_disk-book',
          bookId: 'disk-book', deviceId: 'alice', displayName: 'Alice',
          totalPages: 6, repository: diskContent, voiceStore: voices);
      await diskSync.addNote(3, 'Last week note', shared: false);
      await diskSync.sendText(3, 'Offline message');
      await diskTimes.addReadingTime(id: 'disk-time',
          sessionId: 'solo_disk-book', deviceId: 'alice', additionalSeconds: 32);
      await diskSessions.saveAndLeaveSession('solo_disk-book',
          lastPage: 3, totalPages: 6);
    } finally {
      await disk.close();
    }
    final reopened = AppDatabase.forFile(File('${root.path}/reopen.sqlite'));
    try {
      expect((await SessionRepositoryImpl(reopened)
          .getSessionById('solo_disk-book'))!.status, 'saved');
      expect((await SessionContentRepository(reopened)
          .watchAnnotations('solo_disk-book', 3, 'alice').first).single.content,
          'Last week note');
      expect((await SessionContentRepository(reopened)
          .watchDiscussion('solo_disk-book', 3).first).single.content,
          'Offline message');
      expect((await ParticipantReadingTimeRepositoryImpl(reopened)
          .getTime('solo_disk-book', 'alice'))!.totalSeconds, 32);
      expect(await BookRepositoryImpl(reopened).getBookById('disk-book'), isNotNull);
      final raw = (await reopened.customSelect('SELECT last_page FROM sessions '
          'WHERE id = ?', variables: [Variable.withString('solo_disk-book')])
          .getSingle()).data;
      expect(raw['last_page'], 3);
    } finally {
      await reopened.close();
    }
  });
}
