import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/session_content/voice_audio_service.dart';
import 'package:readmesh/features/lan/lan_connection_state.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import 'package:readmesh/features/room/local_room_service.dart';
import 'package:readmesh/features/room/room_detail_screen.dart';
import 'package:readmesh/features/session_history/my_sessions_screen.dart';

import '../../test_helpers.dart';

class _FakeVoiceAudio implements VoiceAudioService {
  @override
  Future<bool> start(String absolutePath) async => true;
  @override
  Future<int> stop() async => 1000;
  @override
  Future<void> cancel() async {}
  @override
  Future<void> play(String absolutePath) async {}
  @override
  Future<void> stopPlayback() async {}
}

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late BookRepository books;
  late SessionRepository sessions;
  late ReadingProgressRepository progress;
  late DeviceService devices;
  late String deviceId;
  late Book book;

  setUp(() async {
    db = AppDatabase.memory();
    tempDir = await Directory.systemTemp.createTemp('phase6_regression_');
    books = BookRepositoryImpl(db);
    sessions = SessionRepositoryImpl(db);
    progress = ReadingProgressRepositoryImpl(db);
    devices = DeviceService(repository: DeviceProfileRepositoryImpl(db));
    deviceId = (await devices.getOrCreateCurrentProfile()).id;
    final pdf = await TestHelpers.createSamplePdfFile(
      File('${tempDir.path}/book.pdf'), pageCount: 20,
    );
    book = await books.createBook(
      id: 'phase6-book',
      title: 'Phase 6 PDF',
      author: 'Test',
      filePath: pdf.path,
      fileSize: await pdf.length(),
      pageCount: 20,
      sha256Hash: 'phase6-hash',
    );
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('saved page, timestamps and group identity persist; end is irreversible', () async {
    const id = 'RM-PERSIST';
    await sessions.createSession(
      id: id, title: 'Room', hostDeviceId: deviceId,
      bookId: book.id, status: 'active',
    );
    final members = SessionMemberRepositoryImpl(db);
    await members.addMember(
      id: 'member-1', sessionId: id, deviceId: 'phone-b',
      displayName: 'Phone B', role: 'participant', status: 'active',
    );
    await progress.updateProgress(
      id: 'progress-a', sessionId: id, bookId: book.id, deviceId: deviceId,
      currentPage: 5, totalPages: 20,
    );
    expect(await sessions.updateSessionLastPage(id, 5, 20), isTrue);
    expect(await sessions.saveAndLeaveSession(id, lastPage: 5, totalPages: 20), isTrue);
    expect((await sessions.getSavedSessions()).single.status, 'saved');
    final raw = (await db.customSelect(
      'SELECT last_page, total_pages, updated_at, last_activity_at, session_type '
      'FROM sessions WHERE id = ?',
      variables: [Variable.withString(id)],
    ).get()).single.data;
    expect(raw['last_page'], 5);
    expect(raw['total_pages'], 20);
    expect(raw['session_type'], 'group');
    final seconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    expect(raw['updated_at'] as int, inInclusiveRange(seconds - 10, seconds + 10));
    expect(raw['last_activity_at'] as int, inInclusiveRange(seconds - 10, seconds + 10));

    expect(await sessions.updateSessionStatus(id, 'active'), isTrue);
    expect((await progress.getProgress(id, deviceId))!.currentPage, 5);
    expect(await sessions.endReadingSession(id), isTrue);
    expect((await sessions.getSessionById(id))!.status, 'ended');
    expect((await members.getMember(id, 'phone-b'))!.status, 'left');
    expect(await sessions.updateSessionStatus(id, 'active'), isFalse);
    expect(await sessions.saveAndLeaveSession(id), isFalse);
    expect((await sessions.getSavedSessions()).single.status, 'ended');
  });

  test('deleting only session history retains the PDF and removes flags', () async {
    const id = 'solo_phase6-book';
    await sessions.createSession(
      id: id, title: 'Solo', hostDeviceId: deviceId,
      bookId: book.id, status: 'active',
    );
    await sessions.updateSessionFlags(id, timerEnabled: true, statsEnabled: true);
    await sessions.saveAndLeaveSession(id, lastPage: 10, totalPages: 20);
    expect(await sessions.deleteSessionHistoryOnly(id), isTrue);
    expect(await sessions.getSessionById(id), isNull);
    expect(await books.getBookById(book.id), isNotNull);
    expect(await File(book.filePath).exists(), isTrue);
    final flags = await db.customSelect(
      'SELECT key FROM kvs WHERE key IN (?, ?)',
      variables: [Variable.withString('session_${id}_timer'),
                  Variable.withString('session_${id}_stats')],
    ).get();
    expect(flags, isEmpty);
  });

  test('LAN snapshot and pages 1 -> 2 -> 5 -> 10, pause, resume, save, fresh host and end', () async {
    const id = 'RM-LAN-REGRESSION';
    final host = LanHostServer(
      sessionId: id, hostDeviceId: 'phone-a', hostDisplayName: 'Host',
      initialPage: 5, totalPages: 20, sessionStatus: 'active',
      requestedPort: 0,
    );
    final participant = LanParticipantClient(
      sessionId: id, deviceId: 'phone-b', displayName: 'Participant',
      autoReconnect: false,
    );
    addTearDown(() async {
      await participant.disconnect();
      participant.dispose();
      await host.stop();
      host.dispose();
    });
    await host.start(bindAddress: InternetAddress.loopbackIPv4);
    final snapshotFuture = participant.messageStream
        .firstWhere((m) => m.type == LanMessageType.stateSnapshot)
        .timeout(const Duration(seconds: 3));
    await participant.connect(
      hostAddress: InternetAddress.loopbackIPv4.address, port: host.port,
    );
    final snapshot = await snapshotFuture;
    expect(snapshot.currentPage, 5);
    expect(snapshot.totalPages, 20);
    expect(participant.hasJoinAck, isTrue);
    expect(participant.isJoined, isTrue);

    final pages = <int>[];
    final pageTen = Completer<void>();
    final pageSub = participant.pageStream.listen((page) {
      // The total MUST already be updated when the page event is delivered.
      expect(participant.totalPages, 20);
      pages.add(page);
      if (page == 10 && !pageTen.isCompleted) pageTen.complete();
    });
    for (final page in [1, 2, 5, 10]) {
      host.broadcastPageChange(page, 20);
    }
    await pageTen.future.timeout(const Duration(seconds: 3));
    expect(pages, containsAllInOrder([1, 2, 5, 10]));
    await pageSub.cancel();

    final paused = participant.statusStream.firstWhere((s) => s == 'paused');
    host.broadcastSessionPaused();
    expect(await paused.timeout(const Duration(seconds: 3)), 'paused');
    final resumed = participant.statusStream.firstWhere((s) => s == 'active');
    host.broadcastSessionResumed();
    expect(await resumed.timeout(const Duration(seconds: 3)), 'active');

    final saved = participant.statusStream.firstWhere((s) => s == 'saved');
    host.broadcastSessionSaved();
    await host.stop();
    expect(await saved.timeout(const Duration(seconds: 3)), 'saved');
    expect(participant.state, LanConnectionState.disconnected);
    await participant.reconnect();
    expect(participant.state, LanConnectionState.disconnected);

    // Resuming uses a new server/socket, with authoritative saved page 10.
    final newHost = LanHostServer(
      sessionId: id, hostDeviceId: 'phone-a', hostDisplayName: 'Host',
      initialPage: 10, totalPages: 20, sessionStatus: 'active',
      requestedPort: 0,
    );
    final newParticipant = LanParticipantClient(
      sessionId: id, deviceId: 'phone-b', displayName: 'Participant',
      autoReconnect: false,
    );
    addTearDown(() async {
      await newParticipant.disconnect();
      newParticipant.dispose();
      await newHost.stop();
      newHost.dispose();
    });
    await newHost.start(bindAddress: InternetAddress.loopbackIPv4);
    final newSnapshot = newParticipant.messageStream
        .firstWhere((m) => m.type == LanMessageType.stateSnapshot)
        .timeout(const Duration(seconds: 3));
    await newParticipant.connect(
      hostAddress: InternetAddress.loopbackIPv4.address, port: newHost.port,
    );
    expect((await newSnapshot).currentPage, 10);
    expect(newParticipant.isJoined, isTrue);
    final ended = newParticipant.statusStream.firstWhere((s) => s == 'ended');
    newHost.broadcastSessionEnded();
    await newHost.stop();
    expect(await ended.timeout(const Duration(seconds: 3)), 'ended');
    expect(newParticipant.state, LanConnectionState.disconnected);
    await newParticipant.reconnect();
    expect(newParticipant.state, LanConnectionState.disconnected);
  });

  test('a dropped participant can rejoin the live Host and recover its page', () async {
    final host = LanHostServer(
      sessionId: 'RM-REJOIN', hostDeviceId: 'phone-a',
      hostDisplayName: 'Host', requestedPort: 0, totalPages: 20,
    );
    final guest = LanParticipantClient(
      sessionId: 'RM-REJOIN', deviceId: 'phone-b',
      displayName: 'Guest', autoReconnect: false,
    );
    addTearDown(() async {
      await guest.disconnect();
      guest.dispose();
      await host.stop();
      host.dispose();
    });
    await host.start(bindAddress: InternetAddress.loopbackIPv4);
    final firstSnapshot = guest.messageStream
        .firstWhere((m) => m.type == LanMessageType.stateSnapshot)
        .timeout(const Duration(seconds: 3));
    await guest.connect(
      hostAddress: InternetAddress.loopbackIPv4.address, port: host.port,
    );
    await firstSnapshot;
    expect(guest.isJoined, isTrue);
    await guest.disconnect();
    expect(guest.isJoined, isFalse);
    host.broadcastPageChange(5, 20);
    final secondSnapshot = guest.messageStream
        .firstWhere((m) => m.type == LanMessageType.stateSnapshot)
        .timeout(const Duration(seconds: 3));
    await guest.reconnect();
    expect((await secondSnapshot).currentPage, 5);
    expect(guest.hasJoinAck, isTrue);
    expect(guest.isJoined, isTrue);
    expect(guest.currentPage, 5);
  });

  test('wrong LAN room code never receives joinAck or a snapshot', () async {
    final host = LanHostServer(
      sessionId: 'RM-CORRECT', hostDeviceId: 'phone-a',
      hostDisplayName: 'Host', requestedPort: 0,
    );
    final wrong = LanParticipantClient(
      sessionId: 'RM-WRONG', deviceId: 'phone-b',
      displayName: 'Participant', autoReconnect: false,
    );
    addTearDown(() async {
      await wrong.disconnect();
      wrong.dispose();
      await host.stop();
      host.dispose();
    });
    await host.start(bindAddress: InternetAddress.loopbackIPv4);
    final disconnected = wrong.stateStream
        .firstWhere((s) => s == LanConnectionState.disconnected)
        .timeout(const Duration(seconds: 3));
    await wrong.connect(
      hostAddress: InternetAddress.loopbackIPv4.address, port: host.port,
    );
    await disconnected;
    expect(host.connectedClientCount, 0);
    expect(wrong.hasJoinAck, isFalse);
    expect(wrong.hasSnapshot, isFalse);
    expect(wrong.isJoined, isFalse);
  });

  test('an ended host cannot start a TCP room', () async {
    final ended = LanHostServer(
      sessionId: 'RM-ENDED', hostDeviceId: 'phone-a',
      hostDisplayName: 'Host', sessionStatus: 'ended', requestedPort: 0,
    );
    await expectLater(ended.start(bindAddress: InternetAddress.loopbackIPv4),
        throwsStateError);
    expect(ended.isRunning, isFalse);
    ended.dispose();
  });

  testWidgets('Room Detail back offers End, confirms, and preserves ended history',
      (tester) async {
    const id = 'RM-DETAIL';
    await sessions.createSession(
      id: id, title: 'Host room', hostDeviceId: deviceId,
      bookId: book.id, status: 'active',
    );
    final room = LocalRoomService(
      sessionRepository: sessions,
      sessionMemberRepository: SessionMemberRepositoryImpl(db),
      deviceService: devices, bookRepository: books,
    );
    final host = LanHostServer(
      sessionId: id, hostDeviceId: deviceId,
      hostDisplayName: 'Host', sessionStatus: 'active', requestedPort: 0,
    );
    addTearDown(host.dispose);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        key: const Key('open_room'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => RoomDetailScreen(
            sessionId: id, roomService: room, bookRepository: books,
            progressRepository: progress, deviceService: devices,
            hostServer: host,
          ),
        )),
        child: const Text('Open room'),
      ))),
    ));
    await tester.tap(find.byKey(const Key('open_room')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect(find.byKey(const Key('room_leave_dialog')), findsOneWidget);
    await tester.tap(find.text('End Reading Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('room_confirm_end_dialog')), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byKey(const Key('room_confirm_end_dialog')),
      matching: find.text('End Reading Session'),
    ));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect((await sessions.getSessionById(id))!.status, 'ended');
    expect((await sessions.getSavedSessions()).single.status, 'ended');
    expect(find.byKey(const Key('open_room')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an ended personal session leaves the PDF readable as a new session',
      (tester) async {
    final endedId = 'solo_${book.id}';
    await sessions.createSession(
      id: endedId, title: 'Old reading', hostDeviceId: deviceId,
      bookId: book.id, status: 'ended',
    );
    await tester.pumpWidget(MaterialApp(
      home: PdfReaderScreen(
        book: book, readingProgressRepository: progress,
        sessionRepository: sessions, deviceService: devices,
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect(find.byKey(const Key('next_page_button')), findsOneWidget);
    final next = tester.widget<IconButton>(find.byKey(const Key('next_page_button')));
    expect(next.onPressed, isNotNull);
    final all = await sessions.getAllSessions();
    expect(all.where((s) => s.id == endedId).single.status, 'ended');
    expect(all.where((s) => s.id.startsWith('solo_${book.id}_') &&
        s.status == 'active'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PDF -> Save and Leave -> My Sessions -> resume page -> end -> delete history',
      (tester) async {
    // These are UI navigation assertions, not a substitute for real pdfx/Android.
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        key: const Key('open_reader'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => PdfReaderScreen(
            book: book, readingProgressRepository: progress,
            sessionRepository: sessions, deviceService: devices,
          ),
        )),
        child: const Text('Open PDF'),
      ))),
    ));
    await tester.tap(find.byKey(const Key('open_reader')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect(find.byKey(const Key('page_number_display')), findsOneWidget);
    await tester.tap(find.byKey(const Key('next_page_button')));
    await tester.pump();
    expect(find.text('Page 2 of 20'), findsWidgets);
    for (var page = 3; page <= 10; page++) {
      await tester.tap(find.byKey(const Key('next_page_button')));
      await tester.pump();
    }
    expect(find.text('Page 10 of 20'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('leave_session_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save_and_leave_button')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect(find.byKey(const Key('open_reader')), findsOneWidget);
    expect((await sessions.getSavedSessions()).single.status, 'saved');

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: MySessionsScreen(
        sessionRepository: sessions, bookRepository: books,
        progressRepository: progress, deviceService: devices,
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    final historyId = 'solo_${book.id}';
    expect((await progress.getProgress(historyId, deviceId))?.currentPage, 10);
    expect(find.byKey(Key('session_card_$historyId')), findsOneWidget);
    expect(find.text('Page 10 of 20'), findsWidgets);
    await tester.tap(find.byKey(Key('resume_session_$historyId')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect(find.text('Page 10 of 20'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('end_reading_session_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm_end_button')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect((await sessions.getSessionById(historyId))!.status, 'ended');
    expect(find.byKey(Key('session_card_$historyId')), findsOneWidget);
    final resume = tester.widget<ElevatedButton>(
      find.byKey(Key('resume_session_$historyId')),
    );
    expect(resume.onPressed, isNull);
    await tester.tap(find.byKey(Key('delete_session_$historyId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('confirm_delete_button')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    expect(await sessions.getSessionById(historyId), isNull);
    expect(await books.getBookById(book.id), isNotNull);
    expect(await File(book.filePath).exists(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Save & Leave commits saved/page in SQLite across a cold reopen; only End writes ended', () async {
    const id = 'RM-SAVE-DURABLE';
    final sqliteFile = File('${tempDir.path}/session-history.db');
    final first = AppDatabase.forFile(sqliteFile);
    try {
      await BookRepositoryImpl(first).createBook(
        id: book.id, title: book.title, author: book.author,
        filePath: book.filePath, fileSize: book.fileSize,
        pageCount: book.pageCount, sha256Hash: book.sha256Hash,
      );
      final repo = SessionRepositoryImpl(first);
      await repo.createSession(id: id, title: 'Group reading',
          hostDeviceId: deviceId, bookId: book.id, status: 'active');
      expect(await repo.saveAndLeaveSession(id, lastPage: 10, totalPages: 20), isTrue);
      final row = (await first.customSelect(
        'SELECT status, last_page, total_pages, last_activity_at, updated_at '
        'FROM sessions WHERE id = ?', variables: [Variable.withString(id)],
      ).get()).single.data;
      expect(row['status'], 'saved');
      expect(row['last_page'], 10);
      expect(row['total_pages'], 20);
      final seconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      expect(row['updated_at'] as int, inInclusiveRange(seconds - 10, seconds + 10));
      expect(row['last_activity_at'] as int, inInclusiveRange(seconds - 10, seconds + 10));
      expect(await repo.updateSessionLastPage(id, 1, 20), isFalse);
      expect(await repo.updateSessionStatus(id, 'ended'), isFalse);
      expect(await repo.updateSessionStatus(id, 'saved'), isFalse);
    } finally {
      await first.close();
    }
    final reopened = AppDatabase.forFile(sqliteFile);
    try {
      final repo = SessionRepositoryImpl(reopened);
      expect(await repo.recoverInterruptedSessions(), 0);
      expect((await repo.getSessionById(id))!.status, 'saved');
      expect((await reopened.customSelect('SELECT last_page FROM sessions WHERE id = ?',
          variables: [Variable.withString(id)]).get()).single.data['last_page'], 10);
      expect(await repo.updateSessionStatus(id, 'active'), isTrue);
      expect(await repo.endReadingSession(id), isTrue);
      expect((await repo.getSessionById(id))!.status, 'ended');
      expect(await repo.saveAndLeaveSession(id), isFalse);
      expect(await repo.updateSessionStatus(id, 'active'), isFalse);
      expect(await BookRepositoryImpl(reopened).getBookById(book.id), isNotNull);
    } finally {
      await reopened.close();
    }
  });

  testWidgets('opening PDF wires Notes, Discussion, Voice and Highlight to reader UI; Save writes saved',
      (tester) async {
    final content = SessionContentRepository(db);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'), supportedLocales: const [Locale('en')],
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        key: const Key('open_phase6_reader'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            PdfReaderScreen(book: book, readingProgressRepository: progress,
                sessionRepository: sessions, deviceService: devices,
                contentRepository: content, voiceStore: SessionVoiceStore(tempDir),
                audioService: _FakeVoiceAudio(),
                showLegacySessionContent: true))),
        child: const Text('Read now'),
      ))),
    ));
    await tester.tap(find.byKey(const Key('open_phase6_reader')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.byKey(const Key('reader_notes_discussion')), findsOneWidget);
    expect(find.byKey(const Key('reader_highlight')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reader_notes_discussion')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new_page_note')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('new_page_note')), 'Visible in PDF reader');
    await tester.tap(find.byKey(const Key('save_page_note')));
    await tester.pumpAndSettle();
    final note = (await content.watchAnnotations('solo_${book.id}', 1, deviceId,
        kind: 'note').first).single;
    expect(note.content, 'Visible in PDF reader');
    expect(find.byKey(Key('pin_note_${note.id}')), findsOneWidget);
    await tester.tap(find.text('Discussion'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start_voice_recording')), findsOneWidget);
    expect(find.byKey(const Key('new_page_message')), findsOneWidget);
    await tester.binding.handlePopRoute(); // Dismiss bottom sheet.
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute(); // Back from the reader.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('save_and_leave_button')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.byKey(const Key('open_phase6_reader')), findsOneWidget);
    expect((await sessions.getSessionById('solo_${book.id}'))!.status, 'saved');
    expect((await content.watchAnnotations('solo_${book.id}', 1, deviceId,
        kind: 'note').first).single.content, 'Visible in PDF reader');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saved Group Resume binds a fresh Host before activating the same room code',
      (tester) async {
    const id = 'RM-RESUME-GROUP';
    await sessions.createSession(id: id, title: 'Saved group',
        hostDeviceId: deviceId, bookId: book.id, status: 'saved');
    await progress.updateProgress(id: 'group-host-progress', sessionId: id,
        bookId: book.id, deviceId: deviceId, currentPage: 10, totalPages: 20);
    final room = LocalRoomService(sessionRepository: sessions,
        sessionMemberRepository: SessionMemberRepositoryImpl(db),
        deviceService: devices, bookRepository: books);
    final host = LanHostServer(sessionId: id, hostDeviceId: deviceId,
        hostDisplayName: 'Host', initialPage: 10, totalPages: 20,
        sessionStatus: 'active', requestedPort: 0);
    addTearDown(host.dispose);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'), supportedLocales: const [Locale('en')],
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        key: const Key('open_saved_group'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            RoomDetailScreen(sessionId: id, resumeSavedSession: true,
                roomService: room, bookRepository: books, progressRepository: progress,
                deviceService: devices, hostServer: host,
                contentRepository: SessionContentRepository(db),
                voiceStore: SessionVoiceStore(tempDir)))),
        child: const Text('Resume room'),
      ))),
    ));
    await tester.tap(find.byKey(const Key('open_saved_group')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(host.isRunning, isTrue);
    expect(host.currentPage, 10);
    expect((await sessions.getSessionById(id))!.status, 'active');
    expect(find.byKey(const Key('room_code_display')), findsOneWidget);
    expect(find.byKey(const Key('share_room_code_button')), findsOneWidget);
    final openBook = tester.widget<ElevatedButton>(
        find.byKey(const Key('open_room_book_button')));
    expect(openBook.onPressed, isNotNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('room_save_and_leave_button')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect((await sessions.getSessionById(id))!.status, 'saved');
    expect(host.isRunning, isFalse);
    expect((await progress.getProgress(id, deviceId))!.currentPage, 10);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed Group Resume cannot leave a ghost active room in SQLite',
      (tester) async {
    const id = 'RM-PORT-TAKEN';
    await sessions.createSession(id: id, title: 'Saved room',
        hostDeviceId: deviceId, bookId: book.id, status: 'saved');
    final occupied = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    addTearDown(occupied.close);
    final host = LanHostServer(sessionId: id, hostDeviceId: deviceId,
        hostDisplayName: 'Host', sessionStatus: 'active',
        requestedPort: occupied.port);
    addTearDown(host.dispose);
    final room = LocalRoomService(sessionRepository: sessions,
        sessionMemberRepository: SessionMemberRepositoryImpl(db),
        deviceService: devices, bookRepository: books);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'), supportedLocales: const [Locale('en')],
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: RoomDetailScreen(sessionId: id, resumeSavedSession: true,
          roomService: room, bookRepository: books, progressRepository: progress,
          deviceService: devices, hostServer: host),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(host.isRunning, isFalse);
    expect((await sessions.getSessionById(id))!.status, 'saved');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
