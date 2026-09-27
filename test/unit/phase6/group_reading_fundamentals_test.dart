import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/room/local_room_service.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_controller.dart';

import '../../test_helpers.dart';

// Two separate SQLite files represent two phones. Reopening one discards all
// RAM-only identity, page, roster and message state, not just the socket.
class _Phone {
  final File file;
  _Phone(this.file);
  late final AppDatabase db;
  late final BookRepositoryImpl books;
  late final SessionRepositoryImpl sessions;
  late final SessionMemberRepositoryImpl members;
  late final ReadingProgressRepositoryImpl progress;
  late final MessageRepositoryImpl messages;
  late final DeviceService devices;
  late final LocalRoomService rooms;

  Future<void> open() async {
    db = AppDatabase.forFile(file);
    books = BookRepositoryImpl(db);
    sessions = SessionRepositoryImpl(db);
    members = SessionMemberRepositoryImpl(db);
    progress = ReadingProgressRepositoryImpl(db);
    messages = MessageRepositoryImpl(db);
    devices = DeviceService(repository: DeviceProfileRepositoryImpl(db));
    rooms = LocalRoomService(sessionRepository: sessions,
        sessionMemberRepository: members, deviceService: devices,
        bookRepository: books);
  }
}

void main() {
  test('A-G: matching PDF join, live pages/text, save, cold reopen, same member and reconnect',
      () async {
    const room = 'RM-FOUNDATIONS';
    final root = await Directory.systemTemp.createTemp('readmesh_group_acceptance_');
    final hostFile = File('${root.path}/host.sqlite');
    final peerFile = File('${root.path}/participant.sqlite');
    final host = _Phone(hostFile);
    final peer = _Phone(peerFile);
    await host.open();
    await peer.open();
    _Phone? reopenedPeer;
    _Phone? reopenedHost;
    var peerClosed = false;
    var hostClosed = false;
    LanHostServer? server;
    LanParticipantClient? client;
    LanParticipantClient? returned;
    SessionContentSync? hostSync;
    SessionContentSync? peerSync;
    SessionContentSync? returnedSync;
    try {
      final hostPdf = await TestHelpers.createSamplePdfFile(
          File('${root.path}/host.pdf'), pageCount: 16);
      final peerPdf = await hostPdf.copy('${root.path}/peer.pdf');
      final digest = sha256.convert(await hostPdf.readAsBytes()).toString();
      await host.books.createBook(id: 'host-book', title: 'Shared PDF',
          author: 'Local', filePath: hostPdf.path,
          fileSize: await hostPdf.length(), pageCount: 16,
          sha256Hash: digest);
      // Importing the same PDF on another phone assigns a different book ID.
      // An unrelated book happens to be first in its Library.
      await peer.books.createBook(id: 'peer-book', title: 'Shared PDF',
          author: 'Local', filePath: peerPdf.path,
          fileSize: await peerPdf.length(), pageCount: 16,
          sha256Hash: digest);
      final otherPdf = await TestHelpers.createSamplePdfFile(
          File('${root.path}/other.pdf'), pageCount: 3);
      await peer.books.createBook(id: 'wrong-book', title: 'Other PDF',
          author: 'Local', filePath: otherPdf.path,
          fileSize: await otherPdf.length(), pageCount: 3,
          sha256Hash: sha256.convert(await otherPdf.readAsBytes()).toString());
      // Make the unrelated import unambiguously first in the old Library
      // ordering; a fallback to books.first would now open the wrong PDF.
      await peer.db.customStatement(
          'UPDATE books SET created_at = ? WHERE id = ?', [
        DateTime.now().toUtc().add(const Duration(days: 1))
            .millisecondsSinceEpoch ~/ 1000,
        'wrong-book',
      ]);
      expect((await peer.books.getAllBooks()).first.id, 'wrong-book');

      final hostProfile = await host.devices.getOrCreateCurrentProfile();
      final peerProfile = await peer.devices.getOrCreateCurrentProfile();
      final created = await host.rooms.createRoom(title: 'Shared reading',
          bookId: 'host-book', customSessionCode: room);
      expect(created.id, room);
      expect(await host.rooms.startSession(room), isTrue);
      expect((await host.members.getMember(room, hostProfile.id))!.role, 'host');

      final hostServer = LanHostServer(sessionId: room, hostDeviceId: hostProfile.id,
          hostDisplayName: hostProfile.displayName, bookSha256: digest,
          initialPage: 1, totalPages: 16, sessionStatus: 'active',
          requestedPort: 0);
      server = hostServer;
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      final hostBridge = SessionContentSync(sessionId: room, bookId: 'host-book',
          deviceId: hostProfile.id, displayName: hostProfile.displayName,
          totalPages: 16, repository: SessionContentRepository(host.db),
          voiceStore: SessionVoiceStore(Directory('${root.path}/host_voice')),
          host: hostServer)..start();
      hostSync = hostBridge;
      final peerClient = LanParticipantClient(sessionId: room, deviceId: peerProfile.id,
          displayName: peerProfile.displayName, autoReconnect: false);
      client = peerClient;
      final peerBridge = SessionContentSync(sessionId: room, bookId: 'peer-book',
          deviceId: peerProfile.id, displayName: peerProfile.displayName,
          totalPages: 16, repository: SessionContentRepository(peer.db),
          voiceStore: SessionVoiceStore(Directory('${root.path}/peer_voice')),
          participant: peerClient)..start();
      peerSync = peerBridge;

      // Test A: JOIN -> joinAck -> stateSnapshot, two local copies of *one*
      // session with the same PDF bytes, not the first unrelated library book.
      final ack = peerClient.messageStream.firstWhere((m) =>
          m.type == LanMessageType.joinAck).timeout(const Duration(seconds: 5));
      final snapshot = peerClient.messageStream.firstWhere((m) =>
          m.type == LanMessageType.stateSnapshot).timeout(const Duration(seconds: 5));
      await peerClient.connect(hostAddress: InternetAddress.loopbackIPv4.address,
          port: hostServer.port);
      expect((await ack).senderDeviceId, hostProfile.id);
      final initial = await snapshot;
      expect(initial.payload?['bookSha256'], digest);
      expect(initial.currentPage, 1);
      expect(peerClient.isJoined, isTrue);
      final joined = await peer.rooms.joinRoom(sessionCode: room,
          remoteHostDeviceId: initial.senderDeviceId,
          remoteBookSha256: initial.payload?['bookSha256'] as String?);
      expect(joined.id, created.id);
      expect(joined.bookId, 'peer-book');
      final peerMember = (await peer.members.getMember(room, peerProfile.id))!;
      await host.rooms.syncConnectedParticipants(room, {
        peerProfile.id: peerProfile.displayName,
      });
      final hostMember = (await host.members.getMember(room, peerProfile.id))!;
      expect(hostServer.connectedClientCount, 1);

      // Test B: live Host page event (no refresh/re-entry) and Host-only
      // leadership. The Reader widget exercises the pageStream -> PDF UI link.
      final pageFive = peerClient.pageStream.firstWhere((p) => p == 5)
          .timeout(const Duration(seconds: 5));
      await host.progress.updateProgress(id: 'host-progress', sessionId: room,
          bookId: 'host-book', deviceId: hostProfile.id,
          currentPage: 5, totalPages: 16);
      await host.sessions.updateSessionLastPage(room, 5, 16);
      hostServer.broadcastPageChange(5, 16);
      expect(await pageFive, 5);
      expect(peerClient.totalPages, 16);
      await peer.progress.updateProgress(id: 'peer-progress', sessionId: room,
          bookId: 'peer-book', deviceId: peerProfile.id,
          currentPage: peerClient.currentPage, totalPages: peerClient.totalPages);
      await peer.sessions.updateSessionLastPage(room, peerClient.currentPage, 16);
      final attempted = hostServer.messageStream.firstWhere((m) =>
          m.type == LanMessageType.pageChanged &&
          m.senderDeviceId == peerProfile.id)
          .timeout(const Duration(seconds: 5));
      peerClient.send(LanMessage.pageChanged(sessionId: room,
          hostDeviceId: peerProfile.id, currentPage: 9, totalPages: 16));
      await attempted;
      expect(hostServer.currentPage, 5); // Participant cannot change Host page.
      expect(peerClient.currentPage, 5);

      // Tests C/D: both directions traverse real TCP and two independent
      // Drift watchPageText streams, using the committed row's original ID.
      final peerComposer = TextMessagesController(repository: peer.messages,
          sessionId: room, senderId: peerProfile.id,
          senderName: peerProfile.displayName);
      final hostComposer = TextMessagesController(repository: host.messages,
          sessionId: room, senderId: hostProfile.id,
          senderName: hostProfile.displayName);
      final onHost = host.messages.watchPageText(room, 5).firstWhere(
          (rows) => rows.any((row) => row.text == 'Peer at five'))
          .timeout(const Duration(seconds: 5));
      final fromPeer = await peerComposer.send(5, 'Peer at five');
      expect(await peerBridge.publishCommittedText(fromPeer), isTrue);
      expect((await onHost).single.id, fromPeer.id);
      final onPeer = peer.messages.watchPageText(room, 5).firstWhere(
          (rows) => rows.any((row) => row.text == 'Host at five'))
          .timeout(const Duration(seconds: 5));
      final fromHost = await hostComposer.send(5, 'Host at five');
      expect(await hostBridge.publishCommittedText(fromHost), isTrue);
      expect((await onPeer).map((row) => row.id),
          containsAll([fromPeer.id, fromHost.id]));

      // Test E: the group reached page 10/16. Save & Leave on B retains its
      // own persisted session, book, page and text even after DB/process close.
      final pageTen = peerClient.pageStream.firstWhere((p) => p == 10)
          .timeout(const Duration(seconds: 5));
      await host.sessions.updateSessionLastPage(room, 10, 16);
      hostServer.broadcastPageChange(10, 16);
      expect(await pageTen, 10);
      await peer.progress.updateProgress(id: 'peer-progress', sessionId: room,
          bookId: 'peer-book', deviceId: peerProfile.id,
          currentPage: peerClient.currentPage, totalPages: peerClient.totalPages);
      expect(await peer.rooms.saveAndLeaveSession(room,
          lastPage: 10, totalPages: 16), isTrue);
      await peer.rooms.leaveRoom(room);
      await peerBridge.dispose();
      peerSync = null;
      final left = hostServer.participantsStream.firstWhere((list) => list.isEmpty)
          .timeout(const Duration(seconds: 5));
      await peerClient.disconnect();
      await left;
      peerClient.dispose();
      client = null;
      await host.rooms.syncConnectedParticipants(room, const <String, String>{});
      expect((await host.members.getMember(room, peerProfile.id))!.status,
          'disconnected');
      await peer.db.close();
      peerClosed = true;

      final recoveredPeer = _Phone(peerFile);
      reopenedPeer = recoveredPeer;
      await recoveredPeer.open();
      final sameProfile = await recoveredPeer.devices.getOrCreateCurrentProfile();
      expect(sameProfile.id, peerProfile.id);
      final saved = (await recoveredPeer.sessions.getSessionById(room))!;
      expect(saved.status, 'saved');
      expect(saved.bookId, 'peer-book');
      expect((await recoveredPeer.sessions.getSessionPage(room))!.page, 10);
      expect((await recoveredPeer.books.getBookById(saved.bookId))!.sha256Hash,
          digest);
      expect(await File((await recoveredPeer.books.getBookById(saved.bookId))!
          .filePath).exists(), isTrue);
      expect((await recoveredPeer.messages.getPageText(room, 5))
          .map((m) => m.id), containsAll([fromPeer.id, fromHost.id]));
      expect((await recoveredPeer.members.getMember(room, peerProfile.id))!.id,
          peerMember.id);

      // Tests F/G: new app + socket, same profile/session/member/book and a
      // fresh Host snapshot at 10. Reattach content after TCP preflight and
      // prove that later live pages still arrive on this new connection.
      final returnClient = LanParticipantClient(sessionId: room, deviceId: sameProfile.id,
          displayName: sameProfile.displayName, autoReconnect: false);
      returned = returnClient;
      final backAck = returnClient.messageStream.firstWhere((m) =>
          m.type == LanMessageType.joinAck).timeout(const Duration(seconds: 5));
      final backSnapshot = returnClient.messageStream.firstWhere((m) =>
          m.type == LanMessageType.stateSnapshot)
          .timeout(const Duration(seconds: 5));
      await returnClient.connect(hostAddress: InternetAddress.loopbackIPv4.address,
          port: hostServer.port);
      await backAck;
      final restored = await backSnapshot;
      expect(restored.currentPage, 10);
      expect(restored.totalPages, 16);
      expect(restored.payload?['bookSha256'], digest);
      expect(returnClient.isJoined, isTrue);
      final existing = await recoveredPeer.rooms.joinRoom(sessionCode: room,
          remoteHostDeviceId: restored.senderDeviceId,
          remoteBookSha256: restored.payload?['bookSha256'] as String?);
      expect(existing.id, room);
      expect(existing.bookId, 'peer-book');
      await recoveredPeer.rooms.startSession(room);
      await host.rooms.syncConnectedParticipants(room, {
        sameProfile.id: sameProfile.displayName,
      });
      expect((await host.members.getMember(room, sameProfile.id))!.id,
          hostMember.id);
      expect((await recoveredPeer.members.getMember(room, sameProfile.id))!.id,
          peerMember.id);
      expect((await recoveredPeer.sessions.getAllSessions())
          .where((s) => s.id == room), hasLength(1));
      expect((await recoveredPeer.members.getMembersBySessionId(room))
          .where((m) => m.deviceId == sameProfile.id), hasLength(1));
      expect(hostServer.connectedClientCount, 1);
      final returnBridge = SessionContentSync(sessionId: room, bookId: 'peer-book',
          deviceId: sameProfile.id, displayName: sameProfile.displayName,
          totalPages: 16,
          repository: SessionContentRepository(recoveredPeer.db),
          voiceStore: SessionVoiceStore(Directory('${root.path}/returned_voice')),
          participant: returnClient)..start();
      returnedSync = returnBridge;
      final pageEleven = returnClient.pageStream.firstWhere((p) => p == 11)
          .timeout(const Duration(seconds: 5));
      hostServer.broadcastPageChange(11, 16);
      expect(await pageEleven, 11);
      await host.sessions.updateSessionLastPage(room, 11, 16);
      final receivedOnHost = host.messages.watchPageText(room, 11).firstWhere(
          (rows) => rows.any((row) => row.text == 'Peer after reconnect'))
          .timeout(const Duration(seconds: 5));
      final resumedComposer = TextMessagesController(
          repository: recoveredPeer.messages, sessionId: room,
          senderId: sameProfile.id, senderName: sameProfile.displayName);
      final afterReconnect = await resumedComposer.send(11, 'Peer after reconnect');
      expect(await returnBridge.publishCommittedText(afterReconnect), isTrue);
      expect((await receivedOnHost).single.id, afterReconnect.id);
      final receivedOnPeer = recoveredPeer.messages.watchPageText(room, 11)
          .firstWhere((rows) => rows.any(
              (row) => row.text == 'Host after reconnect'))
          .timeout(const Duration(seconds: 5));
      final hostAfterReconnect = await hostComposer.send(11, 'Host after reconnect');
      expect(await hostBridge.publishCommittedText(hostAfterReconnect), isTrue);
      expect((await receivedOnPeer).map((row) => row.id),
          containsAll([afterReconnect.id, hostAfterReconnect.id]));
      expect((await recoveredPeer.messages.getPageText(room, 5))
          .map((m) => m.id), containsAll([fromPeer.id, fromHost.id]));

      // The Host's durable page is independent of its device-progress row.
      // Even if its last per-device write is stale (5), the new shared page
      // and messages survive a separate Host cold restart too.
      await returnBridge.dispose();
      returnedSync = null;
      await returnClient.disconnect();
      returnClient.dispose();
      returned = null;
      await hostBridge.dispose();
      hostSync = null;
      await hostServer.stop();
      hostServer.dispose();
      server = null;
      expect(await host.rooms.saveAndLeaveSession(room,
          lastPage: 11, totalPages: 16), isTrue);
      await host.db.close();
      hostClosed = true;
      final recoveredHost = _Phone(hostFile);
      reopenedHost = recoveredHost;
      await recoveredHost.open();
      expect(await recoveredHost.sessions.recoverInterruptedSessions(), 0);
      expect((await recoveredHost.members.getMember(room, peerProfile.id))!.id,
          hostMember.id);
      expect((await recoveredHost.members.getMember(room, peerProfile.id))!.status,
          'disconnected');
      expect((await recoveredHost.sessions.getSessionById(room))!.bookId,
          'host-book');
      expect((await recoveredHost.sessions.getSessionPage(room))!.page, 11);
      final staleProgress = (await recoveredHost.progress.getProgress(
          room, hostProfile.id))!;
      expect(staleProgress.currentPage, 5);
      expect((await recoveredHost.messages.getPageText(room, 5)), hasLength(2));
      final durable = (await recoveredHost.sessions.getSessionPage(room))!;
      final freshHost = LanHostServer(sessionId: room,
          hostDeviceId: hostProfile.id,
          hostDisplayName: hostProfile.displayName,
          bookSha256: digest, initialPage: durable.page,
          totalPages: 16, sessionStatus: 'active', requestedPort: 0);
      final freshClient = LanParticipantClient(sessionId: room,
          deviceId: sameProfile.id, displayName: sameProfile.displayName,
          autoReconnect: false);
      try {
        await freshHost.start(bindAddress: InternetAddress.loopbackIPv4);
        expect(await recoveredHost.rooms.resumeSession(room), isTrue);
        await recoveredHost.rooms.joinRoom(sessionCode: room);
        final freshSnapshot = freshClient.messageStream.firstWhere((m) =>
            m.type == LanMessageType.stateSnapshot)
            .timeout(const Duration(seconds: 5));
        await freshClient.connect(hostAddress: InternetAddress.loopbackIPv4.address,
            port: freshHost.port);
        expect((await freshSnapshot).currentPage, 11);
        expect((await recoveredHost.sessions.getAllSessions())
            .where((s) => s.id == room), hasLength(1));
      } finally {
        await freshClient.disconnect();
        freshClient.dispose();
        await freshHost.stop();
        freshHost.dispose();
      }
    } finally {
      await returnedSync?.dispose();
      await peerSync?.dispose();
      await hostSync?.dispose();
      await returned?.disconnect();
      returned?.dispose();
      await client?.disconnect();
      client?.dispose();
      await server?.stop();
      server?.dispose();
      await reopenedHost?.db.close();
      await reopenedPeer?.db.close();
      if (!hostClosed) await host.db.close();
      if (!peerClosed) await peer.db.close();
      await root.delete(recursive: true);
    }
  });

  test('F/G: saved legacy room repairs wrong book without replacing member, page or text',
      () async {
    const id = 'RM-LEGACY-BOOK';
    final db = AppDatabase.memory();
    try {
      final books = BookRepositoryImpl(db);
      await books.createBook(id: 'old-book', title: 'Other PDF',
          author: 'Local', filePath: 'old.pdf', fileSize: 1,
          pageCount: 16, sha256Hash: 'other-hash');
      await books.createBook(id: 'right-book', title: 'Same as Host',
          author: 'Local', filePath: 'right.pdf', fileSize: 1,
          pageCount: 16, sha256Hash: 'matching-hash');
      final sessions = SessionRepositoryImpl(db);
      final members = SessionMemberRepositoryImpl(db);
      final progress = ReadingProgressRepositoryImpl(db);
      final messages = MessageRepositoryImpl(db);
      final devices = DeviceService(repository: DeviceProfileRepositoryImpl(db));
      final profile = await devices.getOrCreateCurrentProfile();
      final rooms = LocalRoomService(sessionRepository: sessions,
          sessionMemberRepository: members, deviceService: devices,
          bookRepository: books);
      await sessions.createSession(id: id, title: 'Previous join',
          hostDeviceId: 'same-host', bookId: 'old-book', status: 'active');
      await members.addMember(id: 'stable-member', sessionId: id,
          deviceId: profile.id, displayName: profile.displayName,
          role: 'participant', status: 'left');
      await progress.updateProgress(id: 'stable-progress', sessionId: id,
          bookId: 'old-book', deviceId: profile.id,
          currentPage: 10, totalPages: 16);
      final text = await messages.createText(id: 'old-text', sessionId: id,
          pageNumber: 10, senderId: profile.id,
          senderName: profile.displayName, text: 'Before restart');
      await sessions.saveAndLeaveSession(id, lastPage: 10, totalPages: 16);
      final joined = await rooms.joinRoom(sessionCode: id,
          remoteHostDeviceId: 'same-host',
          remoteBookSha256: 'matching-hash');
      expect(joined.id, id);
      expect(joined.bookId, 'right-book');
      expect((await progress.getProgress(id, profile.id))!.bookId,
          'right-book');
      expect((await sessions.getSessionPage(id))!.page, 10);
      expect((await members.getMember(id, profile.id))!.id, 'stable-member');
      expect((await messages.getPageText(id, 10)).single.id, text.id);
      expect((await sessions.getAllSessions()).where((s) => s.id == id),
          hasLength(1));
      await expectLater(rooms.joinRoom(sessionCode: id,
          remoteHostDeviceId: 'other-host',
          remoteBookSha256: 'matching-hash'), throwsA(isA<Exception>()));
      expect((await sessions.getSessionById(id))!.hostDeviceId, 'same-host');
    } finally {
      await db.close();
    }
  });

  test('A: wrong or missing PDF cannot silently attach an unrelated local book',
      () async {
    final db = AppDatabase.memory();
    try {
      final books = BookRepositoryImpl(db);
      await books.createBook(id: 'not-host-book', title: 'Other PDF',
          author: 'Local', filePath: 'other.pdf', fileSize: 1,
          pageCount: 3, sha256Hash: 'other-pdf');
      final sessions = SessionRepositoryImpl(db);
      final devices = DeviceService(repository: DeviceProfileRepositoryImpl(db));
      final rooms = LocalRoomService(sessionRepository: sessions,
          sessionMemberRepository: SessionMemberRepositoryImpl(db),
          deviceService: devices, bookRepository: books);
      await expectLater(rooms.joinRoom(sessionCode: 'RM-SAME-BOOK',
          remoteHostDeviceId: 'host', remoteBookSha256: 'host-pdf'),
          throwsA(isA<Exception>()));
      // A snapshot without a fingerprint must not fall back to books.first.
      await expectLater(rooms.joinRoom(sessionCode: 'RM-SAME-BOOK',
          remoteHostDeviceId: 'host'), throwsA(isA<Exception>()));
      expect(await sessions.getSessionById('RM-SAME-BOOK'), isNull);
      expect(await SessionMemberRepositoryImpl(db)
          .getMembersBySessionId('RM-SAME-BOOK'), isEmpty);
    } finally {
      await db.close();
    }
  });
}
