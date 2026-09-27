import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_controller.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_panel.dart';

const _room = 'RM-VOICE-LAN';
const _book = 'identical-pdf-on-both-phones';

class _Phone {
  final AppDatabase db = AppDatabase.memory();
  final Directory root;
  late final SessionRepository sessions = SessionRepositoryImpl(db);
  late final SessionContentRepository content = SessionContentRepository(db);
  late final MessageRepository messages = MessageRepositoryImpl(db);
  late final ReadingProgressRepository progress = ReadingProgressRepositoryImpl(db);
  late final ParticipantReadingTimeRepository times = ParticipantReadingTimeRepositoryImpl(db);
  late final SessionVoiceStore voices = SessionVoiceStore(root);
  _Phone(this.root);

  Future<void> seed() async {
    await BookRepositoryImpl(db).createBook(id: _book, title: 'PDF',
        author: 'Author', filePath: '${root.path}/book.pdf', fileSize: 100,
        pageCount: 20, sha256Hash: 'same-pdf');
    await sessions.createSession(id: _room, title: 'Reading room',
        hostDeviceId: 'host', bookId: _book, status: 'active');
  }

  SessionContentSync bridge(String id, {LanHostServer? host,
      LanParticipantClient? participant, int totalPages = 20}) => SessionContentSync(
    sessionId: _room, bookId: _book, deviceId: id,
    displayName: id, totalPages: totalPages, repository: content,
    voiceStore: voices, progressRepository: progress,
    readingTimeRepository: times, host: host, participant: participant,
  )..start();
}

Future<void> _awaitJoin(LanParticipantClient client, LanHostServer host) async {
  final ack = client.messageStream.firstWhere((m) =>
      m.type == LanMessageType.stateSnapshot).timeout(const Duration(seconds: 5));
  await client.connect(hostAddress: InternetAddress.loopbackIPv4.address,
      port: host.port);
  await ack;
  expect(client.hasJoinAck, isTrue);
  expect(client.isJoined, isTrue);
}

void main() {
  late Directory temp;
  late _Phone a, b, c;
  late LanHostServer server;
  late LanParticipantClient clientB, clientC;
  late SessionContentSync syncA, syncB, syncC;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('phase6_lan_');
    a = _Phone(Directory('${temp.path}/a'));
    b = _Phone(Directory('${temp.path}/b'));
    c = _Phone(Directory('${temp.path}/c'));
    await a.seed(); await b.seed(); await c.seed();
    server = LanHostServer(sessionId: _room, hostDeviceId: 'host',
        hostDisplayName: 'Host', initialPage: 1, totalPages: 20,
        sessionStatus: 'active', requestedPort: 0);
    clientB = LanParticipantClient(sessionId: _room, deviceId: 'phone-b',
        displayName: 'Phone B', autoReconnect: false);
    clientC = LanParticipantClient(sessionId: _room, deviceId: 'phone-c',
        displayName: 'Phone C', autoReconnect: false);
    await server.start(bindAddress: InternetAddress.loopbackIPv4);
    syncA = a.bridge('host', host: server);
    syncB = b.bridge('phone-b', participant: clientB);
    syncC = c.bridge('phone-c', participant: clientC);
    await _awaitJoin(clientB, server);
  });

  tearDown(() async {
    await syncA.dispose(); await syncB.dispose(); await syncC.dispose();
    await clientB.disconnect(); await clientC.disconnect();
    clientB.dispose(); clientC.dispose();
    await server.stop(); server.dispose();
    await a.db.close(); await b.db.close(); await c.db.close();
    await temp.delete(recursive: true);
  });

  test('Host relays only shared page notes/highlights, pins and Unicode discussion', () async {
    final secret = await syncB.addNote(5, 'Personal only', shared: false);
    final sharedSeen = a.content.watchAnnotations(_room, 5, 'host').firstWhere(
        (list) => list.any((n) => n.content == 'Shared note'))
        .timeout(const Duration(seconds: 5));
    final note = await syncB.addNote(5, 'Shared note', shared: true);
    await sharedSeen;
    expect(await a.content.watchAnnotations(_room, 5, 'host').first,
        hasLength(1));
    expect(await a.content.watchAnnotations(_room, 5, 'unrelated-viewer').first,
        hasLength(1));
    expect((await b.content.watchAnnotations(_room, 5, 'phone-b').first).length, 2);
    // Even an explicitly forged personal packet must never leave the device.
    await clientB.sendAndFlush(LanMessage.contentUpsert(
        sessionId: _room, deviceId: 'phone-b', content: secret.toWire()));
    final pinSeen = a.content.watchAnnotations(_room, 5, 'host').firstWhere(
        (list) => list.isNotEmpty && list.single.isPinned)
        .timeout(const Duration(seconds: 5));
    await syncB.setPinned(note, true);
    expect((await pinSeen).single.id, note.id);
    expect(await a.content.sharedAnnotations(_room), hasLength(1));
    expect((await a.content.watchAnnotations(_room, 6, 'host').first), isEmpty);

    final markSeen = b.content.watchAnnotations(_room, 10, 'phone-b',
        kind: 'highlight').firstWhere((list) => list.isNotEmpty)
        .timeout(const Duration(seconds: 5));
    final mark = await syncA.addHighlight(10, 0.2, 0.3, 0.4, 0.1,
        shared: true, color: '#FFD54F');
    expect((await markSeen).single.id, mark.id);
    expect(await b.content.watchAnnotations(_room, 11, 'phone-b',
        kind: 'highlight').first, isEmpty);

    final hostMessage = a.content.watchDiscussion(_room, 10).firstWhere(
        (list) => list.any((m) => m.content == 'مرحبا 🌟'))
        .timeout(const Duration(seconds: 5));
    await syncB.sendText(10, 'مرحبا 🌟');
    expect((await hostMessage).single.authorId, 'phone-b');
    final wrongSender = LanMessage.contentUpsert(sessionId: _room,
        deviceId: 'not-phone-b', content: (await syncB.sendText(11, 'Valid')).toWire());
    await clientB.sendAndFlush(wrongSender);
    final validSeen = a.content.watchDiscussion(_room, 11).firstWhere(
        (list) => list.isNotEmpty).timeout(const Duration(seconds: 5));
    await validSeen;
    expect((await a.content.watchDiscussion(_room, 11).first).length, 1,
        reason: 'Host ignores content with a forged joined-socket sender ID');
  });

  test('Reader text crosses real TCP in both directions, commits once and wakes Drift', () async {
    // Model RoomsScreen's preflight: the same client stays connected while
    // RoomDetail attaches its sync after the snapshot (no replacement socket).
    await syncC.dispose();
    final beforeJoinSender = TextMessagesController(repository: a.messages,
        sessionId: _room, senderId: 'host', senderName: 'Host');
    final beforeJoin = await beforeJoinSender.send(6, 'Saved before peer joined');
    expect(await syncA.publishCommittedText(beforeJoin), isTrue);
    final preflight = clientC.messageStream.listen((_) {});
    final missedBacklog = clientC.messageStream.firstWhere((packet) =>
        packet.type == LanMessageType.contentUpsert &&
        packet.payload?['id'] == beforeJoin.id).timeout(const Duration(seconds: 5));
    try {
      await _awaitJoin(clientC, server);
      await missedBacklog;
      expect(await c.messages.getPageText(_room, 6), isEmpty,
          reason: 'The preflight listener cannot persist the first backlog');
      expect(server.connectedClientCount, 2);
      final catchUp = c.messages.watchPageText(_room, 6).firstWhere(
          (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
      // This phone has no local page count at attach time. The Host snapshot
      // authorizes pages beyond the fallback of 1. Attaching late asks for
      // saved content on the same socket, without a second join or listener.
      syncC = c.bridge('phone-c', participant: clientC, totalPages: 1);
      expect((await catchUp).single.id, beforeJoin.id);
      // Keep a separate observer, just as the preflight does: broadcasts
      // must not consume each other's messages.
      final relayed = <LanMessage>[];
      final wireSub = clientC.messageStream.listen((packet) {
        if (packet.type == LanMessageType.contentUpsert) relayed.add(packet);
      });
      try {
        final fromB = TextMessagesController(repository: b.messages,
            sessionId: _room, senderId: 'phone-b', senderName: 'Phone B');
        final fromA = TextMessagesController(repository: a.messages,
            sessionId: _room, senderId: 'host', senderName: 'Host');
        final fromCController = TextMessagesController(repository: c.messages,
            sessionId: _room, senderId: 'phone-c', senderName: 'Phone C');

        final aSeesB = a.messages.watchPageText(_room, 7).firstWhere(
            (rows) => rows.any((row) => row.text == 'من ب إلى أ'))
            .timeout(const Duration(seconds: 5));
        final cSeesB = c.content.watchDiscussion(_room, 7).firstWhere(
            (rows) => rows.any((row) => row.content == 'من ب إلى أ'))
            .timeout(const Duration(seconds: 5));
        final bRow = await fromB.send(7, 'من ب إلى أ');
        expect((await b.messages.getPageText(_room, 7)).single.id, bRow.id,
            reason: 'The local DB commits before LAN publication');
        final hostWire = server.messageStream.firstWhere((packet) =>
            packet.type == LanMessageType.contentUpsert &&
            packet.payload?['id'] == bRow.id).timeout(const Duration(seconds: 5));
        expect(await syncB.publishCommittedText(bRow), isTrue);
        expect((await hostWire).senderDeviceId, 'phone-b');
        expect((await aSeesB).single.id, bRow.id);
        expect((await cSeesB).single.id, bRow.id);
        expect((await b.messages.getPageText(_room, 7)), hasLength(1),
            reason: 'The Host echo has the same ID, not a second row');

        final bSeesA = b.messages.watchPageText(_room, 10).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final cSeesA = c.messages.watchPageText(_room, 10).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final longArabic = 'مرحبا ' + List.filled(700, '🌟').join();
        final aRow = await fromA.send(10, longArabic);
        expect(await syncA.publishCommittedText(aRow), isTrue);
        expect((await bSeesA).single.text, longArabic);
        expect((await cSeesA).single.id, aRow.id);
        // JSON-escaped yet valid text can exceed the old 4 KB receive guard.
        final escaped = 'مرحبا ' + List.filled(900, '\u0001').join() + ' 🌟';
        expect(jsonEncode(escaped).length, greaterThan(4096));
        final escapedOnB = b.messages.watchPageText(_room, 16).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final escapedRow = await fromA.send(16, escaped);
        expect(await syncA.publishCommittedText(escapedRow), isTrue);
        expect((await escapedOnB).single.text, escaped);
        expect(await c.messages.getPageText(_room, 9), isEmpty,
            reason: 'Page filtering is still handled by SQLite');

        final aSeesC = a.messages.watchPageText(_room, 15).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final bSeesC = b.messages.watchPageText(_room, 15).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final cRow = await fromCController.send(15, 'من ج إلى أ');
        expect(await syncC.publishCommittedText(cRow), isTrue);
        expect((await aSeesC).single.id, cRow.id);
        expect((await bSeesC).single.id, cRow.id);

        // The older discussion sheet's sendText uses the same transport and
        // table. Both generations of Reader must display each other's text.
        final legacyOnB = b.messages.watchPageText(_room, 8).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final legacy = await syncA.sendText(8, 'Legacy host text');
        expect((await legacyOnB).single.id, legacy.id);
        final legacyOnA = a.messages.watchPageText(_room, 9).firstWhere(
            (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
        final olderPeer = await syncB.sendText(9, 'Legacy peer text');
        expect((await legacyOnA).single.id, olderPeer.id);

        // A replay of the same ID may arrive on the existing socket. Wait
        // for a subsequent marker over that socket instead of sleeping or
        // polling to prove that the Host did not relay the duplicate again.
        final repeated = server.messageStream.firstWhere((packet) =>
            packet.type == LanMessageType.contentUpsert &&
            packet.payload?['id'] == bRow.id).timeout(const Duration(seconds: 5));
        expect(await syncB.publishCommittedText(bRow), isTrue);
        await repeated;
        final cSeesMarker = c.messages.watchPageText(_room, 7).firstWhere(
            (rows) => rows.length == 2).timeout(const Duration(seconds: 5));
        final marker = await fromB.send(7, 'ordered marker');
        expect(await syncB.publishCommittedText(marker), isTrue);
        expect((await cSeesMarker).map((m) => m.id), contains(marker.id));
        expect(relayed.where((packet) => packet.payload?['id'] == bRow.id),
            hasLength(1));
        expect(await a.messages.getPageText(_room, 7), hasLength(2));
        expect(await b.messages.getPageText(_room, 7), hasLength(2));
        expect(await c.messages.getPageText(_room, 7), hasLength(2));
        // The old discussion UI reads these very same rows.
        expect((await a.content.watchDiscussion(_room, 7).first)
            .where((m) => m.id == bRow.id), hasLength(1));
      } finally {
        await wireSub.cancel();
        // The preflight listener remains until the room is left.
      }
    } finally {
      await preflight.cancel();
    }
  });

  test('preflight peer can request missed text after Host sync attached first', () async {
    await syncA.dispose();
    await syncC.dispose();
    final sender = TextMessagesController(repository: a.messages,
        sessionId: _room, senderId: 'host', senderName: 'Host');
    final saved = await sender.send(17, 'Host text before both bridges');
    final preflight = clientC.messageStream.listen((_) {});
    try {
      await _awaitJoin(clientC, server);
      // The Host subscribes *after* JOIN, but before the participant's
      // content listener. Its initial backlog reaches only the preflight.
      final initialPacket = clientC.messageStream.firstWhere((packet) =>
          packet.type == LanMessageType.contentUpsert &&
          packet.payload?['id'] == saved.id).timeout(const Duration(seconds: 5));
      syncA = a.bridge('host', host: server);
      await initialPacket;
      expect(await c.messages.getPageText(_room, 17), isEmpty);

      final requested = server.messageStream.firstWhere((packet) =>
          packet.type == LanMessageType.contentReplayRequest &&
          packet.senderDeviceId == 'phone-c').timeout(const Duration(seconds: 5));
      final onPeer = c.messages.watchPageText(_room, 17).firstWhere((rows) =>
          rows.any((row) => row.id == saved.id)).timeout(const Duration(seconds: 5));
      syncC = c.bridge('phone-c', participant: clientC);
      await requested;
      expect((await onPeer).single.id, saved.id,
          reason: 'The initial backlog must not consume the later catch-up');
      expect(server.connectedClientCount, 2,
          reason: 'Catch-up uses the original TCP socket, not a second join');
      expect(await c.messages.getPageText(_room, 17), hasLength(1));
    } finally {
      await preflight.cancel();
    }
  });

  test('Host sync attaching after join catches a missed one-shot request', () async {
    await syncA.dispose();
    await syncB.dispose();
    final hostSender = TextMessagesController(repository: a.messages,
        sessionId: _room, senderId: 'host', senderName: 'Host');
    final row = await hostSender.send(18, 'Host backlog before listener');
    final requestSeen = server.messageStream.firstWhere((packet) =>
        packet.type == LanMessageType.contentReplayRequest &&
        packet.senderDeviceId == 'phone-b').timeout(const Duration(seconds: 5));
    syncB = b.bridge('phone-b', participant: clientB);
    await requestSeen;
    expect(await b.messages.getPageText(_room, 18), isEmpty);
    final catchUp = b.messages.watchPageText(_room, 18).firstWhere(
        (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
    syncA = a.bridge('host', host: server);
    expect((await catchUp).single.id, row.id);
    expect(server.connectedClientCount, 1);
  });

  test('committed Reader text stays offline and replays by ID on the same client', () async {
    await clientB.disconnect();
    final sender = TextMessagesController(repository: b.messages,
        sessionId: _room, senderId: 'phone-b', senderName: 'Phone B');
    final saved = await sender.send(13, 'Offline message');
    expect(await syncB.publishCommittedText(saved), isFalse);
    expect((await b.messages.getPageText(_room, 13)).single.id, saved.id);
    expect(await a.messages.getPageText(_room, 13), isEmpty);
    final onHost = a.messages.watchPageText(_room, 13).firstWhere(
        (rows) => rows.isNotEmpty).timeout(const Duration(seconds: 5));
    await _awaitJoin(clientB, server);
    expect((await onHost).single.id, saved.id);
    expect((await b.messages.getPageText(_room, 13)).single.id, saved.id);
    expect(server.connectedClientCount, 1);
  });

  testWidgets('inline Reader composer Send updates the other phone without reopening',
      (tester) async {
    final hostController = TextMessagesController(repository: a.messages,
        sessionId: _room, senderId: 'host', senderName: 'Host');
    final peerController = TextMessagesController(repository: b.messages,
        sessionId: _room, senderId: 'phone-b', senderName: 'Phone B');
    Widget phone(String key, String id, String name,
        TextMessagesController controller, SessionContentSync sync) =>
        Expanded(child: SizedBox(key: Key(key), height: 400,
          child: TextMessagesPanel(sessionId: _room, pageNumber: 4,
            senderId: id, senderName: name, canSend: true,
            controller: controller,
            publishCommittedText: sync.publishCommittedText)));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: SizedBox(height: 400,
        child: Row(children: [
          phone('host_panel', 'host', 'Host', hostController, syncA),
          phone('peer_panel', 'phone-b', 'Phone B', peerController, syncB),
        ])))),
    ));
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 30)));
    await tester.pump();

    Future<void> sendFrom(String key, String text) async {
      final panel = find.byKey(Key(key));
      await tester.enterText(find.descendant(of: panel,
          matching: find.byKey(const Key('text_message_input'))), text);
      await tester.pump();
      await tester.tap(find.descendant(of: panel,
          matching: find.byKey(const Key('send_text_message_button'))));
    }

    await sendFrom('host_panel', 'أهلاً من المضيف');
    final onPeer = await tester.runAsync(() => b.messages.watchPageText(_room, 4)
        .firstWhere((rows) => rows.any((m) => m.text == 'أهلاً من المضيف'))
        .timeout(const Duration(seconds: 5)));
    expect(onPeer, isNotNull);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('peer_panel')),
        matching: find.byKey(Key('message_body_${onPeer!.single.id}'))),
        findsOneWidget);

    await sendFrom('peer_panel', 'Hello from peer');
    final onHost = await tester.runAsync(() => a.messages.watchPageText(_room, 4)
        .firstWhere((rows) => rows.any((m) => m.text == 'Hello from peer'))
        .timeout(const Duration(seconds: 5)));
    expect(onHost, isNotNull);
    await tester.pumpAndSettle();
    final received = onHost!.singleWhere((m) => m.text == 'Hello from peer');
    expect(find.descendant(of: find.byKey(const Key('host_panel')),
        matching: find.byKey(Key('message_body_${received.id}'))),
        findsOneWidget);
    expect(await a.messages.getPageText(_room, 4), hasLength(2));
    expect(await b.messages.getPageText(_room, 4), hasLength(2));
    // Detach both Drift subscriptions before tearDown closes their databases.
    await tester.pumpWidget(const SizedBox());
  });

  test('voice chunks, hash, replay for late peer, progress and time per device', () async {
    final received = a.content.watchDiscussion(_room, 7).firstWhere((list) =>
        list.any((m) => m.kind == 'voice')).timeout(const Duration(seconds: 8));
    final source = await b.voices.fileFor(_room, 'voice_lan_test');
    final audio = Uint8List.fromList(List<int>.generate(35000, (i) => i % 251));
    await source.writeAsBytes(audio);
    await syncB.sendVoice(7, source, 1300, messageId: 'voice_lan_test');
    final onHost = (await received).single;
    expect(onHost.authorId, 'phone-b');
    expect(onHost.voiceBytes, audio.length);
    expect(await (await a.voices.fileFor(_room, onHost.id)).readAsBytes(), audio);
    expect(onHost.toWire().containsKey('voicePath'), isFalse);

    final lateVoice = c.content.watchDiscussion(_room, 7).firstWhere((list) =>
        list.any((m) => m.kind == 'voice')).timeout(const Duration(seconds: 10));
    await _awaitJoin(clientC, server);
    expect((await lateVoice).single.id, 'voice_lan_test');
    expect(await (await c.voices.fileFor(_room, 'voice_lan_test')).readAsBytes(), audio);
    expect(await c.content.watchDiscussion(_room, 6).first, isEmpty);

    final progressSeen = a.progress.watchSessionProgress(_room).firstWhere(
        (list) => list.any((p) => p.deviceId == 'phone-b' && p.currentPage == 10))
        .timeout(const Duration(seconds: 5));
    await syncB.reportProgress(10, 20);
    final progressRows = await progressSeen;
    expect(progressRows.singleWhere((p) => p.deviceId == 'phone-b').totalPages, 20);
    final hostTime = a.times.watchSessionTimes(_room).firstWhere((list) =>
        list.any((t) => t.deviceId == 'phone-b' && t.totalSeconds == 25))
        .timeout(const Duration(seconds: 5));
    await syncB.reportReadingTime(25);
    expect((await hostTime).single.totalSeconds, 25);
    await syncB.reportReadingTime(10); // delayed packet must not decrement
    final cTime = a.times.watchSessionTimes(_room).firstWhere((list) =>
        list.any((t) => t.deviceId == 'phone-c' && t.totalSeconds == 40))
        .timeout(const Duration(seconds: 5));
    await syncC.reportReadingTime(40);
    await cTime;
    expect((await a.times.getTime(_room, 'phone-b'))!.totalSeconds, 25);
    expect((await a.times.getTime(_room, 'phone-c'))!.totalSeconds, 40);
  });

  test('reconnect retries offline-authored messages and retained voice without new session', () async {
    await clientB.disconnect();
    final note = await syncB.addNote(12, 'Written offline', shared: true);
    await syncB.sendText(12, 'Offline discussion');
    final file = await b.voices.fileFor(_room, 'voice_offline');
    final bytes = Uint8List.fromList(List<int>.generate(20000, (i) => i % 227));
    await file.writeAsBytes(bytes);
    await syncB.sendVoice(12, file, 900, messageId: 'voice_offline');
    await b.times.addReadingTime(id: 'b-time', sessionId: _room,
        deviceId: 'phone-b', additionalSeconds: 14);
    await b.progress.updateProgress(id: 'b-progress', sessionId: _room,
        bookId: _book, deviceId: 'phone-b', currentPage: 12, totalPages: 20);
    expect(await a.content.sharedAnnotations(_room), isEmpty);
    final sharedSeen = a.content.watchAnnotations(_room, 12, 'host')
        .firstWhere((list) => list.any((n) => n.id == note.id))
        .timeout(const Duration(seconds: 8));
    final voiceSeen = a.content.watchDiscussion(_room, 12)
        .firstWhere((list) => list.any((m) => m.kind == 'voice'))
        .timeout(const Duration(seconds: 10));
    await _awaitJoin(clientB, server);
    await sharedSeen;
    final restored = await voiceSeen;
    expect(restored.length, 2);
    expect((await a.progress.getProgress(_room, 'phone-b'))!.currentPage, 12);
    expect((await a.times.getTime(_room, 'phone-b'))!.totalSeconds, 14);
    expect(await (await a.voices.fileFor(_room, 'voice_offline')).readAsBytes(), bytes);
    expect((await a.sessions.getAllSessions()).single.id, _room);
  });
}
