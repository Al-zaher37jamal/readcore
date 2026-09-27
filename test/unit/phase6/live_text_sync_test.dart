import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_content_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/session_voice_store.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/lan/session_content_sync.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_controller.dart';

void main() {
  test('live page text: Participant → Host and Host → Participant via TCP and Drift',
      () async {
    const room = 'RM-LIVE-TEXT';
    const book = 'shared-book';
    final root = await Directory.systemTemp.createTemp('readmesh_live_text_');
    final hostDb = AppDatabase.memory();
    final peerDb = AppDatabase.memory();
    final server = LanHostServer(sessionId: room, hostDeviceId: 'host',
        hostDisplayName: 'Host', totalPages: 12,
        sessionStatus: 'active', requestedPort: 0);
    final client = LanParticipantClient(sessionId: room,
        deviceId: 'participant', displayName: 'Participant',
        autoReconnect: false);
    SessionContentSync? hostSync, peerSync;

    try {
      // Two independent on-device databases; the test cannot accidentally
      // read a shared row without an actual LAN transfer.
      for (final db in [hostDb, peerDb]) {
        await BookRepositoryImpl(db).createBook(id: book, title: 'PDF',
            author: 'Reader', filePath: '${root.path}/book.pdf',
            fileSize: 100, pageCount: 12, sha256Hash: 'same-pdf');
        await SessionRepositoryImpl(db).createSession(id: room,
            title: 'Room', hostDeviceId: 'host', bookId: book,
            status: 'active');
      }
      await server.start(bindAddress: InternetAddress.loopbackIPv4);
      final hostBridge = SessionContentSync(sessionId: room, bookId: book,
          deviceId: 'host', displayName: 'Host', totalPages: 12,
          repository: SessionContentRepository(hostDb),
          voiceStore: SessionVoiceStore(Directory('${root.path}/host')),
          host: server)..start();
      hostSync = hostBridge;
      final peerBridge = SessionContentSync(sessionId: room, bookId: book,
          deviceId: 'participant', displayName: 'Participant', totalPages: 12,
          repository: SessionContentRepository(peerDb),
          voiceStore: SessionVoiceStore(Directory('${root.path}/peer')),
          participant: client)..start();
      peerSync = peerBridge;

      final joined = client.messageStream.firstWhere((packet) =>
          packet.type == LanMessageType.stateSnapshot)
          .timeout(const Duration(seconds: 5));
      await client.connect(hostAddress: InternetAddress.loopbackIPv4.address,
          port: server.port);
      await joined;
      expect(client.isJoined, isTrue);

      final hostMessages = MessageRepositoryImpl(hostDb);
      final peerMessages = MessageRepositoryImpl(peerDb);
      final peerComposer = TextMessagesController(repository: peerMessages,
          sessionId: room, senderId: 'participant', senderName: 'Participant');
      final hostComposer = TextMessagesController(repository: hostMessages,
          sessionId: room, senderId: 'host', senderName: 'Host');

      // Participant → Host: subscribe before sending, so this must be a live
      // Drift emission after the Host receives contentUpsert on its socket.
      final onHost = hostMessages.watchPageText(room, 4).firstWhere((rows) =>
          rows.any((row) => row.text == 'أهلاً من المشارك'))
          .timeout(const Duration(seconds: 5));
      final hostPacket = server.messageStream.firstWhere((packet) =>
          packet.type == LanMessageType.contentUpsert &&
          packet.payload?['content'] == 'أهلاً من المشارك')
          .timeout(const Duration(seconds: 5));
      final fromPeer = await peerComposer.send(4, 'أهلاً من المشارك');
      expect(await peerBridge.publishCommittedText(fromPeer), isTrue);
      expect((await hostPacket).senderDeviceId, 'participant');
      expect((await onHost).single.id, fromPeer.id);

      // Host → Participant: observe both the TCP packet and the *same* live
      // page stream used by TextMessagesPanel; no refresh or re-enter action.
      final onPeer = peerMessages.watchPageText(room, 4).firstWhere((rows) =>
          rows.any((row) => row.text == 'Reply from Host'))
          .timeout(const Duration(seconds: 5));
      final peerPacket = client.messageStream.firstWhere((packet) =>
          packet.type == LanMessageType.contentUpsert &&
          packet.payload?['content'] == 'Reply from Host')
          .timeout(const Duration(seconds: 5));
      final fromHost = await hostComposer.send(4, 'Reply from Host');
      expect(await hostBridge.publishCommittedText(fromHost), isTrue);
      expect((await peerPacket).senderDeviceId, 'host');
      expect((await onPeer).map((row) => row.id), contains(fromHost.id));
      expect(await hostMessages.getPageText(room, 4), hasLength(2));
      expect(await peerMessages.getPageText(room, 4), hasLength(2));
    } finally {
      await hostSync?.dispose();
      await peerSync?.dispose();
      await client.disconnect();
      client.dispose();
      await server.stop();
      server.dispose();
      await hostDb.close();
      await peerDb.close();
      await root.delete(recursive: true);
    }
  });
}
