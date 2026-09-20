import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_connection_state.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_message.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/lan/lan_sync_coordinator.dart';

void main() {
  group('Phase 4: LAN Communication & Reading Synchronization Tests', () {
    late LanHostServer hostServer;
    late LanParticipantClient participantClient;
    const String testSessionId = 'RM-4040';
    const String hostDeviceId = 'dev_host_1';
    const String participantDeviceId = 'dev_part_1';

    setUp(() {
      // Use loopback address and dynamic port (0) for tests
      hostServer = LanHostServer(
        sessionId: testSessionId,
        hostDeviceId: hostDeviceId,
        hostDisplayName: 'Host User',
        initialPage: 1,
        totalPages: 25,
        sessionStatus: 'created',
        requestedPort: 0,
      );

      participantClient = LanParticipantClient(
        sessionId: testSessionId,
        deviceId: participantDeviceId,
        displayName: 'Participant User',
        autoReconnect: false,
      );
    });

    tearDown(() async {
      await participantClient.disconnect();
      participantClient.dispose();
      await hostServer.stop();
      hostServer.dispose();
    });

    test('2. Host startup: binds server socket and reports running', () async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      expect(hostServer.isRunning, isTrue);
      expect(hostServer.port, greaterThan(0));
      expect(hostServer.connectedClientCount, equals(0));
    });

    test('3 & 4. Participant connection and Join Handshake', () async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);

      final stateCompleter = Completer<LanMessage>();
      final sub = participantClient.messageStream.listen((msg) {
        if (msg.type == LanMessageType.stateSnapshot && !stateCompleter.isCompleted) {
          stateCompleter.complete(msg);
        }
      });

      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );

      expect(participantClient.state, equals(LanConnectionState.connected));

      final snapshot = await stateCompleter.future.timeout(const Duration(seconds: 2));
      expect(snapshot.type, equals(LanMessageType.stateSnapshot));
      expect(snapshot.currentPage, equals(1));
      expect(snapshot.totalPages, equals(25));
      expect(snapshot.sessionStatus, equals('created'));

      expect(hostServer.connectedClientCount, equals(1));
      expect(hostServer.participants.first.deviceId, equals(participantDeviceId));

      await sub.cancel();
    });

    test('5. Page synchronization: Host turns page and Participant follows', () async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );

      final pageCompleter = Completer<int>();
      final sub = participantClient.pageStream.listen((page) {
        if (!pageCompleter.isCompleted) {
          pageCompleter.complete(page);
        }
      });

      // Host turns to page 14
      hostServer.broadcastPageChange(14);

      final receivedPage = await pageCompleter.future.timeout(const Duration(seconds: 2));
      expect(receivedPage, equals(14));
      expect(participantClient.currentPage, equals(14));

      await sub.cancel();
    });

    test('6, 7, 8, 9. Session lifecycle synchronization (start, pause, resume, end)', () async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );

      final receivedStatuses = <String>[];
      final statusSub = participantClient.statusStream.listen((status) {
        receivedStatuses.add(status);
      });

      // 6. Start session
      hostServer.broadcastSessionStarted();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedStatuses.last, equals('active'));
      expect(participantClient.sessionStatus, equals('active'));

      // 7. Pause session
      hostServer.broadcastSessionPaused();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedStatuses.last, equals('paused'));
      expect(participantClient.sessionStatus, equals('paused'));

      // 8. Resume session
      hostServer.broadcastSessionResumed();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedStatuses.last, equals('active'));
      expect(participantClient.sessionStatus, equals('active'));

      // 9. End session
      hostServer.broadcastSessionEnded();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedStatuses.last, equals('ended'));
      expect(participantClient.sessionStatus, equals('ended'));

      await statusSub.cancel();
    });

    test('10. Disconnect handling: Participant leaves or socket closes', () async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );
      // Wait for join handshake to be processed by Host
      await Future.delayed(const Duration(milliseconds: 50));
      expect(hostServer.connectedClientCount, equals(1));

      // Participant disconnects
      await participantClient.disconnect();
      expect(participantClient.state, equals(LanConnectionState.disconnected));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(hostServer.connectedClientCount, equals(0));
    });

    test('11 & 12. Reconnect and State Snapshot Restoration', () async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);

      // 1. Initial connection
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );
      expect(participantClient.state, equals(LanConnectionState.connected));

      // 2. Disconnect
      await participantClient.disconnect();
      expect(participantClient.state, equals(LanConnectionState.disconnected));

      // 3. Meanwhile, Host advances the book to page 19
      hostServer.broadcastPageChange(19);

      final snapshotCompleter = Completer<LanMessage>();
      final sub = participantClient.messageStream.listen((msg) {
        if (msg.type == LanMessageType.stateSnapshot && !snapshotCompleter.isCompleted) {
          snapshotCompleter.complete(msg);
        }
      });

      // 4. Participant reconnects
      await participantClient.reconnect();
      expect(participantClient.state, equals(LanConnectionState.connected));

      final restoredSnapshot = await snapshotCompleter.future.timeout(const Duration(seconds: 2));
      expect(restoredSnapshot.currentPage, equals(19));
      expect(participantClient.currentPage, equals(19));

      await sub.cancel();
    });

    test('13. Participant persistence of synchronized page to SQLite via LanSyncCoordinator', () async {
      final db = AppDatabase.memory();
      final bookRepo = BookRepositoryImpl(db);
      final sessionRepo = SessionRepositoryImpl(db);
      final progressRepo = ReadingProgressRepositoryImpl(db);

      // Create test book and session
      final book = await bookRepo.createBook(
        id: 'book-sync-1',
        title: 'Distributed Systems',
        author: 'Tanenbaum',
        filePath: '/tmp/dist.pdf',
        fileSize: 2048,
        pageCount: 30,
        sha256Hash: 'hash-sync-1',
      );

      await sessionRepo.createSession(
        id: 'RM-SYNC',
        title: 'Distributed Study',
        hostDeviceId: 'dev_host_coordinator',
        bookId: book.id,
        status: 'active',
      );

      // Start Host Coordinator
      final hostCoordinator = LanSyncCoordinator(
        sessionId: 'RM-SYNC',
        bookId: book.id,
        deviceId: 'dev_host_coordinator',
        displayName: 'Host Tanenbaum',
        isHost: true,
        readingProgressRepository: progressRepo,
        sessionRepository: sessionRepo,
        initialPage: 1,
        totalPages: 30,
      );
      await hostCoordinator.startHost(port: 0);

      final boundPort = hostCoordinator.hostServer!.port;

      // Start Participant Coordinator
      final participantCoordinator = LanSyncCoordinator(
        sessionId: 'RM-SYNC',
        bookId: book.id,
        deviceId: 'dev_part_coordinator',
        displayName: 'Participant Student',
        isHost: false,
        readingProgressRepository: progressRepo,
        sessionRepository: sessionRepo,
        initialPage: 1,
        totalPages: 30,
      );

      await participantCoordinator.connectParticipant(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: boundPort,
      );

      // Wait for handshake
      await Future.delayed(const Duration(milliseconds: 100));

      // Host turns to page 22
      await hostCoordinator.hostChangePage(22);

      // Wait for LAN broadcast and SQLite write
      await Future.delayed(const Duration(milliseconds: 150));

      // Verify Participant's local SQLite reading_progress was automatically persisted!
      final savedParticipantProgress = await progressRepo.getProgress('RM-SYNC', 'dev_part_coordinator');
      expect(savedParticipantProgress, isNotNull);
      expect(savedParticipantProgress!.currentPage, equals(22));
      expect(savedParticipantProgress.totalPages, equals(30));

      // Clean up
      await participantCoordinator.stop();
      await hostCoordinator.stop();
      await db.close();
    });
  });
}
