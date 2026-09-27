import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/audio_message_repository.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/audio_messages/domain/audio_message.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late SessionVoiceStore files;
  late AudioMessageRepository audio;
  late MessageRepository text;

  Future<void> seed(AppDatabase database) async {
    await BookRepositoryImpl(database).createBook(id: 'book-audio',
      title: 'Offline PDF', author: 'Local', filePath: '/tmp/reader.pdf',
      fileSize: 120, pageCount: 20, sha256Hash: 'phase7-audio-book');
    for (final id in ['solo_audio', 'room_other']) {
      await SessionRepositoryImpl(database).createSession(id: id,
        title: 'Reading', hostDeviceId: 'owner', bookId: 'book-audio',
        status: 'active');
    }
  }

  Future<File> draft(String session, String id) async {
    final file = await files.fileFor(session, 'draft_$id');
    await file.writeAsBytes(List<int>.filled(256, 42), flush: true);
    return file;
  }

  Future<void> send(String id, {String session = 'solo_audio',
      int page = 8, String owner = 'owner'}) async {
    await audio.send(id: id, sessionId: session, pageNumber: page,
      senderId: owner, senderDisplayName: 'أحمد', draft: await draft(session, id),
      durationMs: 2500);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase7_audio_repo_');
    db = AppDatabase.memory();
    await seed(db);
    files = SessionVoiceStore(root);
    audio = AudioMessageRepositoryImpl(db, files);
    text = MessageRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('preview leaves no metadata; Send streams audio on just its session/page',
      () async {
    final watcher = StreamIterator(audio.watchPage('solo_audio', 8));
    expect(await watcher.moveNext(), isTrue);
    expect(watcher.current, isEmpty);
    final first = await draft('solo_audio', 'audio_one');
    expect(await audio.getPage('solo_audio', 8), isEmpty);
    expect(await first.exists(), isTrue);
    final saved = await audio.send(id: 'audio_one', sessionId: 'solo_audio',
      pageNumber: 8, senderId: 'owner', senderDisplayName: 'Reader_device',
      draft: first, durationMs: 2500);
    expect(saved.senderDisplayName, 'Local reader');
    expect(saved.durationMs, 2500);
    expect(saved.status, 'local');
    expect(saved.sha256, isNotEmpty);
    expect(saved.bytes, 256);
    expect(await first.exists(), isFalse);
    expect(await File(saved.audioPath).exists(), isTrue);
    expect(await watcher.moveNext(), isTrue);
    expect(watcher.current.single.id, 'audio_one');
    await watcher.cancel();

    await text.createText(id: 'text-one', sessionId: 'solo_audio',
      pageNumber: 8, senderId: 'owner', senderName: 'أحمد', text: 'Text works');
    await send('audio_other_page', page: 9);
    await send('audio_other_session', session: 'room_other');
    expect((await audio.getPage('solo_audio', 8)).single.id, 'audio_one');
    expect((await audio.getPage('solo_audio', 9)).single.id,
      'audio_other_page');
    expect((await audio.getPage('room_other', 8)).single.id,
      'audio_other_session');
    expect((await text.getPageText('solo_audio', 8)).single.text,
      'Text works');
    expect((await db.customSelect("SELECT message_type FROM messages "
      "WHERE id = 'audio_one'").getSingle()).read<String>('message_type'),
      'audio');
  });

  test('only the owner can replace/delete; old and new files are cleaned',
      () async {
    await send('audio_initial');
    final previous = (await audio.getPage('solo_audio', 8)).single;
    final replacementDraft = await draft('solo_audio', 'audio_replacement');
    await expectLater(audio.send(id: 'audio_replacement',
      sessionId: 'solo_audio', pageNumber: 8, senderId: 'intruder',
      senderDisplayName: 'Intruder', draft: replacementDraft,
      durationMs: 1800, replacing: previous), throwsStateError);
    expect(await replacementDraft.exists(), isTrue);
    expect(await File(previous.audioPath).exists(), isTrue);
    expect(await audio.deleteOwn(previous, 'intruder'), isFalse);
    expect((await audio.getPage('solo_audio', 8)).single.id, 'audio_initial');

    final replaced = await audio.send(id: 'audio_replacement',
      sessionId: 'solo_audio', pageNumber: 8, senderId: 'owner',
      senderDisplayName: 'أحمد', draft: replacementDraft,
      durationMs: 1800, replacing: previous);
    expect(replaced.id, 'audio_replacement');
    expect((await audio.getPage('solo_audio', 8)).single.id,
      'audio_replacement');
    expect(await File(previous.audioPath).exists(), isFalse);
    expect(await File(replaced.audioPath).exists(), isTrue);
    expect(await audio.deleteOwn(replaced, 'intruder'), isFalse);
    expect(await audio.deleteOwn(replaced, 'owner'), isTrue);
    expect(await audio.deleteOwn(replaced, 'owner'), isFalse);
    expect(await File(replaced.audioPath).exists(), isFalse);
    expect(await audio.getPage('solo_audio', 8), isEmpty);
    expect(await audio.pruneUnreferencedFiles(), 0);
  });

  test('invalid path and closed session never commit or lose preview', () async {
    final outside = File('${root.path}/outside.m4a');
    await outside.writeAsBytes([42]);
    await expectLater(audio.send(id: 'audio_bad', sessionId: 'solo_audio',
      pageNumber: 8, senderId: 'owner', senderDisplayName: 'أحمد',
      draft: outside, durationMs: 2000), throwsFormatException);
    await expectLater(audio.send(id: '../invalid',
      sessionId: 'solo_audio', pageNumber: 8, senderId: 'owner',
      senderDisplayName: 'أحمد', draft: outside, durationMs: 2000),
      throwsFormatException);
    final pending = await draft('solo_audio', 'audio_closed');
    await SessionRepositoryImpl(db).saveAndLeaveSession('solo_audio');
    await expectLater(audio.send(id: 'audio_closed',
      sessionId: 'solo_audio', pageNumber: 8, senderId: 'owner',
      senderDisplayName: 'أحمد', draft: pending, durationMs: 2000),
      throwsStateError);
    expect(await pending.exists(), isTrue,
      reason: 'SQLite failure restores the preview for discard/retry');
    expect(await (await files.fileFor('solo_audio', 'audio_closed')).exists(),
      isFalse);
    expect(await audio.getPage('solo_audio', 8), isEmpty);
  });

  test('startup GC removes interrupted drafts/finals, never older voice files',
      () async {
    await send('audio_committed');
    final committed = (await audio.getPage('solo_audio', 8)).single;
    final abandoned = await draft('solo_audio', 'audio_abandoned');
    final orphan = await files.fileFor('solo_audio', 'audio_interrupted');
    await orphan.writeAsBytes([1, 2, 3]);
    final oldPhaseVoice = await files.fileFor('solo_audio', 'voice_legacy');
    await oldPhaseVoice.writeAsBytes([4, 5, 6]);
    expect(await audio.pruneUnreferencedFiles(), 2);
    expect(await abandoned.exists(), isFalse);
    expect(await orphan.exists(), isFalse);
    expect(await oldPhaseVoice.exists(), isTrue);
    expect(await File(committed.audioPath).exists(), isTrue);
  });

  test('offline file-backed reopen retains audio, page and mixed text', () async {
    final diskFile = File('${root.path}/readmesh.sqlite');
    final first = AppDatabase.forFile(diskFile);
    await seed(first);
    final store = SessionVoiceStore(root);
    final repository = AudioMessageRepositoryImpl(first, store);
    final recording = await store.fileFor('solo_audio', 'draft_audio_persist');
    await recording.writeAsBytes(List<int>.filled(512, 37));
    final saved = await HttpOverrides.runZoned<Future<AudioMessage>>(() async {
      final voice = await repository.send(id: 'audio_persist',
        sessionId: 'solo_audio', pageNumber: 8, senderId: 'owner',
        senderDisplayName: 'أحمد', draft: recording, durationMs: 4000);
      await MessageRepositoryImpl(first).createText(id: 'text_persist',
        sessionId: 'solo_audio', pageNumber: 8, senderId: 'owner',
        senderName: 'أحمد', text: 'Offline text');
      return voice;
    }, createHttpClient: (_) => throw StateError('Network is forbidden'));
    await SessionRepositoryImpl(first).saveAndLeaveSession('solo_audio',
      lastPage: 8, totalPages: 20);
    await first.close();

    final reopened = AppDatabase.forFile(diskFile);
    try {
      final afterRestart = AudioMessageRepositoryImpl(reopened, store);
      expect(await afterRestart.pruneUnreferencedFiles(), 0);
      final voices = await afterRestart.getPage('solo_audio', 8);
      expect(voices.single.id, saved.id);
      expect(voices.single.audioPath, saved.audioPath);
      expect(voices.single.durationMs, 4000);
      expect(await File(voices.single.audioPath).exists(), isTrue);
      expect((await MessageRepositoryImpl(reopened)
        .getPageText('solo_audio', 8)).single.text, 'Offline text');
      final session = await SessionRepositoryImpl(reopened)
        .getSessionById('solo_audio');
      expect(session?.status, 'saved');
      expect((await reopened.customSelect(
        "SELECT last_page FROM sessions WHERE id = 'solo_audio'").getSingle())
          .read<int>('last_page'), 8);
    } finally {
      await reopened.close();
    }
  });
}
