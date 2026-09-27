import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';

void main() {
  late AppDatabase db;
  late MessageRepository messages;

  Future<void> seed(AppDatabase database) async {
    final books = BookRepositoryImpl(database);
    final sessions = SessionRepositoryImpl(database);
    await books.createBook(id: 'book-text', title: 'Book', author: 'Local',
      filePath: '/tmp/text.pdf', fileSize: 100, pageCount: 309,
      sha256Hash: 'phase6-text-hash');
    await sessions.createSession(id: 'solo_book-text', title: 'Reading',
      hostDeviceId: 'dev-a', bookId: 'book-text', status: 'active');
    await sessions.createSession(id: 'solo_book-text_other', title: 'Other',
      hostDeviceId: 'dev-a', bookId: 'book-text', status: 'active');
  }

  setUp(() async {
    db = AppDatabase.memory();
    await seed(db);
    messages = MessageRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  test('create/read/live updates are sorted, filtered by session and page', () async {
    final watcher = StreamIterator(messages.watchPageText('solo_book-text', 8));
    expect(await watcher.moveNext(), isTrue);
    expect(watcher.current, isEmpty);
    final first = await messages.createText(id: 'm1',
      sessionId: 'solo_book-text', pageNumber: 8, senderId: 'dev-a',
      senderName: 'أحمد', text: ' السلام عليكم ');
    expect(first.text, 'السلام عليكم');
    expect(first.pageNumber, 8);
    expect(first.senderId, 'dev-a');
    expect(first.status, 'local');
    expect(first.updatedAt, first.createdAt);
    expect(await watcher.moveNext(), isTrue);
    expect(watcher.current.single.id, 'm1');
    await watcher.cancel();
    await messages.createText(id: 'm2', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-b', senderName: 'سارة', text: 'وعليكم السلام');
    await messages.createText(id: 'm3', sessionId: 'solo_book-text',
      pageNumber: 9, senderId: 'dev-a', senderName: 'أحمد', text: 'صفحة 9');
    await messages.createText(id: 'm4', sessionId: 'solo_book-text_other',
      pageNumber: 8, senderId: 'dev-a', senderName: 'أحمد', text: 'جلسة أخرى');
    expect((await messages.getPageText('solo_book-text', 8)).map((m) => m.id),
      ['m1', 'm2']); // same-second inserts keep rowid order
    expect((await messages.getPageText('solo_book-text', 9)).single.id, 'm3');
    expect((await messages.getPageText('solo_book-text_other', 8)).single.id, 'm4');
    expect((await messages.getPageText('solo_book-text', 8)).map((m) => m.text),
      ['السلام عليكم', 'وعليكم السلام']);
  });

  test('validation, sender-owned update and delete; saved rows remain readable', () async {
    await expectLater(messages.createText(id: 'empty', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-a', senderName: 'A', text: '  '),
      throwsFormatException);
    await expectLater(messages.createText(id: 'bad-page', sessionId: 'solo_book-text',
      pageNumber: 0, senderId: 'dev-a', senderName: 'A', text: 'hello'),
      throwsFormatException);
    await messages.createText(id: 'own', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-a', senderName: 'أحمد', text: 'قبل التعديل');
    expect(await messages.updateOwnText(id: 'own', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-b', text: 'مزورة'), isFalse);
    expect(await messages.updateOwnText(id: 'own', sessionId: 'solo_book-text',
      pageNumber: 9, senderId: 'dev-a', text: 'صفحة أخرى'), isFalse);
    expect(await messages.deleteOwnText(id: 'own', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-b'), isFalse);
    expect(await messages.updateOwnText(id: 'own', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-a', text: 'بعد التعديل'), isTrue);
    final updated = (await messages.getPageText('solo_book-text', 8)).single;
    expect(updated.text, 'بعد التعديل');
    expect(updated.updatedAt.isBefore(updated.createdAt), isFalse);
    expect(await SessionRepositoryImpl(db).saveAndLeaveSession('solo_book-text'), isTrue);
    expect((await messages.getPageText('solo_book-text', 8)).single.id, 'own');
    await expectLater(messages.createText(id: 'too-late',
      sessionId: 'solo_book-text', pageNumber: 8, senderId: 'dev-a',
      senderName: 'أحمد', text: 'cannot send'), throwsStateError);
    expect(await messages.deleteOwnText(id: 'own', sessionId: 'solo_book-text',
      pageNumber: 8, senderId: 'dev-a'), isTrue);
    expect(await messages.getPageText('solo_book-text', 8), isEmpty);
  });

  test('legacy text rows remain visible on page 1; system rows are excluded', () async {
    await messages.sendMessage(id: 'old', sessionId: 'solo_book-text',
      senderId: 'dev-a', senderName: 'Reader', content: 'Legacy text');
    await messages.sendMessage(id: 'system', sessionId: 'solo_book-text',
      senderId: 'dev-a', senderName: 'Reader', content: 'joined',
      messageType: 'system');
    expect((await messages.getPageText('solo_book-text', 1)).single.text,
      'Legacy text');
    expect(await messages.getPageText('solo_book-text', 8), isEmpty);
    expect((await messages.getMessages('solo_book-text')).length, 2);
  });

  test('write, close and reopen a file-backed SQLite database', () async {
    final directory = await Directory.systemTemp.createTemp('text_messages_');
    final file = File('${directory.path}/messages.sqlite');
    try {
      final firstDb = AppDatabase.forFile(file);
      final firstRepo = MessageRepositoryImpl(firstDb);
      await seed(firstDb);
      await firstRepo.createText(id: 'persist', sessionId: 'solo_book-text',
        pageNumber: 8, senderId: 'dev-a', senderName: 'أحمد', text: 'السلام عليكم');
      await SessionRepositoryImpl(firstDb).saveAndLeaveSession('solo_book-text',
        lastPage: 8, totalPages: 309);
      final names = (await firstDb.customSelect('PRAGMA table_info(messages)').get())
        .map((row) => row.data['name']).toSet();
      expect(names, containsAll(['session_id', 'page_number', 'sender_id',
        'sender_name', 'content', 'created_at', 'updated_at', 'status']));
      await firstDb.close();

      final reopened = AppDatabase.forFile(file);
      try {
        expect((await reopened.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'], 5);
        final saved = await MessageRepositoryImpl(reopened)
          .getPageText('solo_book-text', 8);
        expect(saved.single.text, 'السلام عليكم');
        expect(saved.single.status, 'local');
        expect(saved.single.sessionId, 'solo_book-text');
        expect((await SessionRepositoryImpl(reopened)
          .getSessionById('solo_book-text'))?.status, 'saved');
      } finally {
        await reopened.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
