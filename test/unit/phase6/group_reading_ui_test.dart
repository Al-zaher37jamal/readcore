import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_page_view.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import 'package:readmesh/features/room/local_room_service.dart';
import 'package:readmesh/features/room/room_detail_screen.dart';
import 'package:readmesh/features/session_history/my_sessions_screen.dart';

import '../../test_helpers.dart';

void main() {
  late Directory root;
  late Book book;
  late String deviceId;
  const room = 'RM-READING-UI';

  Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'), supportedLocales: const [Locale('en')],
    localizationsDelegates: const [AppLocalizationsDelegate()],
    home: home,
  );

  Future<void> letIoComplete(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 180)));
    await tester.pump();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('readmesh_group_ui_');
    await setupLocator(customDatabase: AppDatabase.memory(),
        customStorageDir: root);
    deviceId = (await getIt<DeviceService>().getOrCreateCurrentProfile()).id;
    final pdf = await TestHelpers.createSamplePdfFile(
        File('${root.path}/book.pdf'), pageCount: 16);
    book = await getIt<BookRepository>().createBook(id: 'reader-pdf',
        title: 'Reading Together', author: 'Local', filePath: pdf.path,
        fileSize: await pdf.length(), pageCount: 16,
        sha256Hash: 'same-pdf-digest');
  });

  tearDown(() async {
    await resetLocator();
    await root.delete(recursive: true);
  });

  testWidgets('B: Host Reader page 1 -> 5 broadcasts on TCP, saving page in SQLite',
      (tester) async {
    await getIt<SessionRepository>().createSession(id: room, title: 'Room',
        hostDeviceId: deviceId, bookId: book.id, status: 'active');
    final host = LanHostServer(sessionId: room, hostDeviceId: deviceId,
        hostDisplayName: 'Host', bookSha256: book.sha256Hash,
        initialPage: 1, totalPages: 16, sessionStatus: 'active',
        requestedPort: 0);
    final peer = LanParticipantClient(sessionId: room, deviceId: 'reader-peer',
        displayName: 'Peer', autoReconnect: false);
    try {
      await tester.runAsync(() => host.start(
          bindAddress: InternetAddress.loopbackIPv4));
      final snapshot = peer.messageStream.firstWhere((m) =>
          m.type == LanMessageType.stateSnapshot)
          .timeout(const Duration(seconds: 5));
      await tester.runAsync(() => peer.connect(
          hostAddress: InternetAddress.loopbackIPv4.address,
          port: host.port));
      await tester.runAsync(() => snapshot);
      expect(peer.isJoined, isTrue);

      await tester.pumpWidget(app(PdfReaderScreen(book: book, sessionId: room,
          isHost: true, hostServer: host)));
      await letIoComplete(tester);
      expect(tester.widget<Text>(find.byKey(const Key('page_fraction_display')))
          .data, '1 / 16');
      final pageFive = peer.pageStream.firstWhere((page) => page == 5)
          .timeout(const Duration(seconds: 5));
      final durablePage = getIt<ReadingProgressRepository>()
          .watchSessionProgress(room).firstWhere((rows) => rows.any(
              (row) => row.deviceId == deviceId && row.currentPage == 5))
          .timeout(const Duration(seconds: 5));
      final db = getIt<AppDatabase>();
      final savedRoomPage = db.customSelect(
          'SELECT last_page FROM sessions WHERE id = ?',
          variables: [Variable.withString(room)],
          readsFrom: {db.sessionsTable}).watch().firstWhere((rows) =>
              rows.isNotEmpty && rows.first.data['last_page'] == 5)
          .timeout(const Duration(seconds: 5));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('next_page_button')));
        await tester.pump();
      }
      expect(await tester.runAsync(() => pageFive), 5);
      await tester.runAsync(() => durablePage);
      await tester.runAsync(() => savedRoomPage);
      await tester.pump();
      expect(host.currentPage, 5);
      expect(tester.widget<PdfPageView>(find.byType(PdfPageView)).pageNumber, 5);
      expect((await getIt<SessionRepository>().getSessionPage(room))!.page, 5);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(peer.disconnect);
      peer.dispose();
      await tester.runAsync(host.stop);
      host.dispose();
    }
  });

  testWidgets('B/H: preflight-connected Participant Room/Reader follows Host page, never shows Disconnected',
      (tester) async {
    await getIt<SessionRepository>().createSession(id: room, title: 'Room',
        hostDeviceId: 'another-device', bookId: book.id, status: 'active');
    await getIt<LocalRoomService>().joinRoom(sessionCode: room,
        remoteHostDeviceId: 'another-device',
        remoteBookSha256: book.sha256Hash);
    final host = LanHostServer(sessionId: room,
        hostDeviceId: 'another-device', hostDisplayName: 'Host',
        bookSha256: book.sha256Hash, initialPage: 1,
        totalPages: 16, sessionStatus: 'active', requestedPort: 0);
    final peer = LanParticipantClient(sessionId: room, deviceId: deviceId,
        displayName: 'Peer', autoReconnect: false);
    try {
      await tester.runAsync(() => host.start(
          bindAddress: InternetAddress.loopbackIPv4));
      // RoomsScreen's preflight completes *before* RoomDetail subscribes to
      // the broadcast state stream. The UI must read the live client's state.
      final snapshot = peer.messageStream.firstWhere((m) =>
          m.type == LanMessageType.stateSnapshot)
          .timeout(const Duration(seconds: 5));
      await tester.runAsync(() => peer.connect(
          hostAddress: InternetAddress.loopbackIPv4.address, port: host.port));
      await tester.runAsync(() => snapshot);
      expect(peer.isJoined, isTrue);

      await tester.pumpWidget(app(RoomDetailScreen(sessionId: room,
          hostAddress: InternetAddress.loopbackIPv4.address,
          port: host.port, participantClient: peer)));
      await letIoComplete(tester);
      final status = tester.widget<Text>(find.byKey(
          const Key('lan_connection_status_display'))).data!;
      expect(status, contains('connected'));
      expect(status, isNot(contains('Disconnected')));
      final open = find.byKey(const Key('open_room_book_button'));
      await tester.ensureVisible(open);
      expect(tester.widget<ElevatedButton>(open).onPressed, isNotNull);
      await tester.tap(open);
      await tester.pump();
      await letIoComplete(tester);
      expect(find.byType(PdfReaderScreen), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('page_fraction_display')))
          .data, '1 / 16');
      expect(tester.widget<IconButton>(find.byKey(
          const Key('next_page_button'))).onPressed, isNull,
          reason: 'Only the Host leads group page turns.');

      final pageFive = peer.pageStream.firstWhere((page) => page == 5)
          .timeout(const Duration(seconds: 5));
      final persisted = getIt<ReadingProgressRepository>()
          .watchSessionProgress(room).firstWhere((rows) => rows.any(
              (row) => row.deviceId == deviceId && row.currentPage == 5))
          .timeout(const Duration(seconds: 5));
      host.broadcastPageChange(5, 16);
      expect(await tester.runAsync(() => pageFive), 5);
      await tester.runAsync(() => persisted);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('page_fraction_display')))
          .data, '5 / 16');
      expect(tester.widget<PdfPageView>(find.byType(PdfPageView)).pageNumber, 5);
      expect(peer.currentPage, 5);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(peer.disconnect);
      peer.dispose();
      await tester.runAsync(host.stop);
      host.dispose();
    }
  });

  testWidgets('E: My Sessions and resumed Reader restore durable group page, not stale device progress',
      (tester) async {
    final sessions = getIt<SessionRepository>();
    final progress = getIt<ReadingProgressRepository>();
    await sessions.createSession(id: room, title: 'Same room',
        hostDeviceId: deviceId, bookId: book.id, status: 'active');
    await progress.updateProgress(id: 'stale-host-progress',
        sessionId: room, bookId: book.id, deviceId: deviceId,
        currentPage: 5, totalPages: 16);
    await sessions.saveAndLeaveSession(room, lastPage: 10, totalPages: 16);
    await tester.pumpWidget(app(const MySessionsScreen()));
    await letIoComplete(tester);
    expect(tester.widget<Text>(find.byKey(Key('page_display_$room'))).data,
        'Page 10 of 16');
    expect((await sessions.getSessionById(room))!.status, 'saved');

    // Opening the same group Reader after a Host resume uses the SQLite
    // session page even when its per-device progress still says page 5.
    await sessions.updateSessionStatus(room, 'active');
    await tester.pumpWidget(app(PdfReaderScreen(book: book,
        sessionId: room, isHost: true)));
    await letIoComplete(tester);
    expect(tester.widget<Text>(find.byKey(const Key('page_fraction_display')))
        .data, '10 / 16');
    expect(tester.widget<Text>(find.byKey(const Key('reader_book_title')))
        .data, book.title);
    expect((await sessions.getAllSessions()).where((s) => s.id == room),
        hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('F/G/H: saved Participant opens same room, reconnects and sees page/text immediately',
      (tester) async {
    final sessions = getIt<SessionRepository>();
    final rooms = getIt<LocalRoomService>();
    await sessions.createSession(id: room, title: 'Saved room',
        hostDeviceId: 'live-host', bookId: book.id, status: 'active');
    await rooms.joinRoom(sessionCode: room,
        remoteHostDeviceId: 'live-host', remoteBookSha256: book.sha256Hash);
    final oldMember = (await getIt<SessionMemberRepository>()
        .getMember(room, deviceId))!.id;
    await getIt<MessageRepository>().createText(id: 'saved-text',
        sessionId: room, pageNumber: 10, senderId: deviceId,
        senderName: 'Reader', text: 'Before closing');
    await getIt<ReadingProgressRepository>().updateProgress(
        id: 'stale-peer-progress', sessionId: room, bookId: book.id,
        deviceId: deviceId, currentPage: 5, totalPages: 16);
    await rooms.saveAndLeaveSession(room, lastPage: 10, totalPages: 16);
    await rooms.leaveRoom(room);
    final host = LanHostServer(sessionId: room, hostDeviceId: 'live-host',
        hostDisplayName: 'Host', bookSha256: book.sha256Hash,
        initialPage: 10, totalPages: 16, sessionStatus: 'active',
        requestedPort: 0);
    try {
      await tester.runAsync(() => host.start(
          bindAddress: InternetAddress.loopbackIPv4));
      final joinedSocket = host.participantsStream.firstWhere(
          (list) => list.length == 1).timeout(const Duration(seconds: 5));
      final activated = sessions.watchSessionById(room).firstWhere(
          (session) => session?.status == 'active')
          .timeout(const Duration(seconds: 5));
      await tester.pumpWidget(app(RoomDetailScreen(sessionId: room,
          hostAddress: InternetAddress.loopbackIPv4.address, port: host.port)));
      await tester.runAsync(() => joinedSocket);
      await tester.runAsync(() => activated);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(
          const Key('lan_connection_status_display'))).data,
          contains('connected'));
      expect((await getIt<SessionMemberRepository>()
          .getMember(room, deviceId))!.id, oldMember);
      expect((await sessions.getAllSessions()).where((s) => s.id == room),
          hasLength(1));
      final open = find.byKey(const Key('open_room_book_button'));
      await tester.ensureVisible(open);
      expect(tester.widget<ElevatedButton>(open).onPressed, isNotNull);
      await tester.tap(open);
      await tester.pump();
      await letIoComplete(tester);
      expect(tester.widget<PdfReaderScreen>(find.byType(PdfReaderScreen))
          .book.id, book.id);
      expect(tester.widget<Text>(find.byKey(const Key('page_fraction_display')))
          .data, '10 / 16');
      expect(find.text('Before closing'), findsOneWidget);
      final persisted = getIt<ReadingProgressRepository>()
          .watchSessionProgress(room).firstWhere((rows) => rows.any(
              (row) => row.deviceId == deviceId && row.currentPage == 11))
          .timeout(const Duration(seconds: 5));
      host.broadcastPageChange(11, 16);
      await tester.runAsync(() => persisted);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('page_fraction_display')))
          .data, '11 / 16');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(host.stop);
      host.dispose();
    }
  });

  testWidgets('H/F: live Host roster counts sockets and reuses member on rejoin',
      (tester) async {
    await getIt<LocalRoomService>().createRoom(title: 'Room',
        bookId: book.id, customSessionCode: room);
    final host = LanHostServer(sessionId: room, hostDeviceId: deviceId,
        hostDisplayName: 'Host', bookSha256: book.sha256Hash,
        totalPages: 16, sessionStatus: 'created', requestedPort: 0);
    final peer = LanParticipantClient(sessionId: room, deviceId: 'returning-peer',
        displayName: 'Returning', autoReconnect: false);
    LanParticipantClient? rejoined;
    try {
      await tester.runAsync(() => host.start(
          bindAddress: InternetAddress.loopbackIPv4));
      await tester.pumpWidget(app(RoomDetailScreen(sessionId: room,
          hostServer: host)));
      await letIoComplete(tester);
      final members = getIt<SessionMemberRepository>();
      final firstJoin = members.watchMembersBySessionId(room).firstWhere(
          (rows) => rows.any((m) =>
              m.deviceId == 'returning-peer' && m.status == 'active'))
          .timeout(const Duration(seconds: 5));
      final ack = peer.messageStream.firstWhere((m) =>
          m.type == LanMessageType.stateSnapshot)
          .timeout(const Duration(seconds: 5));
      await tester.runAsync(() => peer.connect(
          hostAddress: InternetAddress.loopbackIPv4.address, port: host.port));
      await tester.runAsync(() => ack);
      await tester.runAsync(() => firstJoin);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('lan_peer_count_display')))
          .data, contains('1'));
      final open = find.byKey(const Key('open_room_book_button'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pump();
      await letIoComplete(tester);
      expect(tester.widget<Text>(find.byKey(
          const Key('reader_participant_count'))).data, '2');
      final rowId = (await members.getMember(room, 'returning-peer'))!.id;
      final noPeer = members.watchMembersBySessionId(room).firstWhere(
          (rows) => rows.any((m) => m.deviceId == 'returning-peer' &&
              m.status == 'disconnected')).timeout(const Duration(seconds: 5));
      await tester.runAsync(peer.disconnect);
      await tester.runAsync(() => noPeer);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(
          const Key('reader_participant_count'))).data, '1');
      peer.dispose();

      final freshPeer = LanParticipantClient(sessionId: room, deviceId: 'returning-peer',
          displayName: 'Returning', autoReconnect: false);
      rejoined = freshPeer;
      final liveAgain = members.watchMembersBySessionId(room).firstWhere(
          (rows) => rows.any((m) => m.deviceId == 'returning-peer' &&
              m.status == 'active')).timeout(const Duration(seconds: 5));
      final secondSnapshot = freshPeer.messageStream.firstWhere((m) =>
          m.type == LanMessageType.stateSnapshot)
          .timeout(const Duration(seconds: 5));
      await tester.runAsync(() => freshPeer.connect(
          hostAddress: InternetAddress.loopbackIPv4.address, port: host.port));
      await tester.runAsync(() => secondSnapshot);
      await tester.runAsync(() => liveAgain);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(
          const Key('reader_participant_count'))).data, '2');
      expect((await members.getMember(room, 'returning-peer'))!.id, rowId);
      expect((await members.getMembersBySessionId(room))
          .where((m) => m.deviceId == 'returning-peer'), hasLength(1));
      expect(host.connectedClientCount, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => rejoined?.disconnect() ?? Future<void>.value());
      rejoined?.dispose();
      await tester.runAsync(host.stop);
      host.dispose();
    }
  });
}
