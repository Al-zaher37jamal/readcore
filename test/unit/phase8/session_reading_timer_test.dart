import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_reading_timer_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/reading_time/domain/session_reading_timer.dart';
import 'package:readmesh/features/reading_time/presentation/session_reading_timer_controller.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late SessionRepositoryImpl sessions;
  late SessionReadingTimerRepositoryImpl timers;
  var now = DateTime.utc(2026, 9, 26, 12);
  const sessionId = 'RM-READING-TIME';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('readmesh_timer_');
    now = DateTime.utc(2026, 9, 26, 12);
    db = AppDatabase.forFile(File('${root.path}/reader.sqlite'));
    sessions = SessionRepositoryImpl(db);
    timers = SessionReadingTimerRepositoryImpl(db, now: () => now);
    await BookRepositoryImpl(db).createBook(id: 'timer-book',
      title: 'Book', author: 'Local', filePath: '${root.path}/book.pdf',
      fileSize: 120, pageCount: 309, sha256Hash: 'timer-sha');
    await sessions.createSession(id: sessionId, title: 'Group',
      hostDeviceId: 'leader', bookId: 'timer-book', status: 'active');
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('v6 adds countdown to existing sessions; leader configures and starts',
      () async {
    final fields = await db.customSelect('PRAGMA table_info(sessions)').get();
    final names = fields.map((row) => row.data['name']).toSet();
    expect(names, containsAll([
      'reading_duration_minutes', 'reading_started_at', 'reading_ends_at',
      'reading_configured_by_leader_id', 'reading_timer_status',
    ]));
    final leader = SessionReadingTimerController(repository: timers,
      sessionRepository: sessions, sessionId: sessionId,
      actorDeviceId: 'leader', now: () => now);
    addTearDown(leader.dispose);
    await leader.load();
    expect(leader.isLeader, isTrue);
    expect(leader.status, ReadingTimerStatus.notConfigured);
    expect(leader.value!.durationMinutes, isNull);

    await leader.configure(30);
    expect(leader.status, ReadingTimerStatus.configured);
    expect(leader.value!.durationMinutes, 30);
    expect(leader.value!.configuredByLeaderId, 'leader');
    expect(leader.remainingSeconds, 1800);
    expect(leader.value!.startedAt, isNull);
    await leader.start();
    expect(leader.status, ReadingTimerStatus.running);
    expect(leader.value!.startedAt, now);
    expect(leader.value!.endsAt, now.add(const Duration(minutes: 30)));
    expect(leader.remainingSeconds, 1800);
    now = now.add(const Duration(seconds: 18));
    leader.refresh();
    expect(leader.remainingSeconds, 1782);
    expect((await sessions.getSessionById(sessionId))!.status, 'active');
    leader.dispose();
  });

  test('participant sees duration but cannot configure or start, even through repository',
      () async {
    await timers.configure(sessionId, 'leader', 75);
    final participant = SessionReadingTimerController(repository: timers,
      sessionRepository: sessions, sessionId: sessionId,
      actorDeviceId: 'participant', now: () => now);
    addTearDown(participant.dispose);
    await participant.load();
    expect(participant.isLeader, isFalse);
    expect(participant.status, ReadingTimerStatus.configured);
    expect(participant.value!.durationMinutes, 75);
    await expectLater(participant.configure(20), throwsStateError);
    await expectLater(participant.start(), throwsStateError);
    await expectLater(timers.configure(sessionId, 'participant', 20),
        throwsStateError);
    await expectLater(timers.start(sessionId, 'participant'),
        throwsStateError);
    expect((await timers.get(sessionId))!.durationMinutes, 75);
    expect((await timers.get(sessionId))!.status,
        ReadingTimerStatus.configured);
  });

  test('valid custom durations persist; invalid and running edits are rejected',
      () async {
    for (final minutes in [20, 75, 120]) {
      expect((await timers.configure(sessionId, 'leader', minutes))
          .durationMinutes, minutes);
    }
    for (final invalid in [0, -1, 1441]) {
      expect(() => timers.configure(sessionId, 'leader', invalid),
          throwsRangeError);
    }
    expect((await timers.get(sessionId))!.durationMinutes, 120);
    await timers.start(sessionId, 'leader');
    await expectLater(timers.configure(sessionId, 'leader', 15),
        throwsStateError);
    await expectLater(timers.start(sessionId, 'leader'), throwsStateError);
    expect((await timers.get(sessionId))!.durationMinutes, 120);
  });

  test('deadline expires without ending session or touching messages and page',
      () async {
    await sessions.updateSessionLastPage(sessionId, 8, 309);
    final text = MessageRepositoryImpl(db);
    await text.createText(id: 'message-1', sessionId: sessionId,
      pageNumber: 8, senderId: 'leader', senderName: 'Leader',
      text: 'Keep this discussion');
    final leader = SessionReadingTimerController(repository: timers,
      sessionRepository: sessions, sessionId: sessionId,
      actorDeviceId: 'leader', now: () => now);
    addTearDown(leader.dispose);
    await leader.load();
    await leader.configure(15);
    await leader.start();
    final finished = timers.watch(sessionId).firstWhere(
      (value) => value?.status == ReadingTimerStatus.finished)
        .timeout(const Duration(seconds: 3));
    final notified = Completer<void>();
    leader.addListener(() {
      if (leader.status == ReadingTimerStatus.finished &&
          !notified.isCompleted) notified.complete();
    });
    now = now.add(const Duration(minutes: 15));
    leader.refresh();
    expect((await finished)!.status, ReadingTimerStatus.finished);
    await notified.future.timeout(const Duration(seconds: 3));
    expect(leader.status, ReadingTimerStatus.finished);
    expect(leader.remainingSeconds, 0);
    expect((await timers.get(sessionId))!.status,
        ReadingTimerStatus.finished);
    expect((await sessions.getSessionById(sessionId))!.status, 'active');
    final row = (await db.customSelect(
      'SELECT last_page FROM sessions WHERE id = ?',
      variables: [Variable.withString(sessionId)],
    ).getSingle()).data;
    expect(row['last_page'], 8);
    expect((await text.getPageText(sessionId, 8)).single.text,
        'Keep this discussion');
  });

  test('same session timer survives closing and reopening SQLite', () async {
    await timers.configure(sessionId, 'leader', 20);
    await timers.start(sessionId, 'leader');
    await db.close();
    db = AppDatabase.forFile(File('${root.path}/reader.sqlite'));
    sessions = SessionRepositoryImpl(db);
    timers = SessionReadingTimerRepositoryImpl(db, now: () => now);
    final restored = await timers.get(sessionId);
    expect(restored!.status, ReadingTimerStatus.running);
    expect(restored.durationMinutes, 20);
    expect(restored.configuredByLeaderId, 'leader');
    expect(restored.remainingSeconds(now), 1200);
    now = now.add(const Duration(minutes: 21));
    expect((await timers.get(sessionId))!.status, ReadingTimerStatus.finished);
    final raw = await db.customSelect(
        'SELECT reading_timer_status FROM sessions WHERE id = ?',
        variables: [Variable.withString(sessionId)]).getSingle();
    expect(raw.data['reading_timer_status'], 'finished');
  });
}
