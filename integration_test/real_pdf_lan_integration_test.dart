import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import '../test/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late AppDatabase db;
  late BookRepository bookRepo;
  late ReadingProgressRepository progressRepo;
  late SessionRepository sessionRepo;
  late DeviceService deviceService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('real_pdf_lan_integration_');
    db = AppDatabase.memory();
    bookRepo = BookRepositoryImpl(db);
    progressRepo = ReadingProgressRepositoryImpl(db);
    sessionRepo = SessionRepositoryImpl(db);
    final profileRepo = DeviceProfileRepositoryImpl(db);
    deviceService = DeviceService(repository: profileRepo);
    await deviceService.getOrCreateCurrentProfile();
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 4 — Real PDF + LAN Integration', () {
    testWidgets('Host real PDF page change -> Participant real PDF viewer sync + persistence',
        (WidgetTester tester) async {
      // Create real PDF file (20 pages)
      final pdfFile = File(p.join(tempDir.path, 'host_real.pdf'));
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 20);

      final book = await bookRepo.createBook(
        id: 'book-host-real',
        title: 'Host Real PDF',
        author: 'Tester',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 20,
        sha256Hash: 'hash-host-real',
      );

      // Host server
      final hostServer = LanHostServer(
        sessionId: 'RM-REAL-1',
        hostDeviceId: 'dev_host_real',
        hostDisplayName: 'Host',
        initialPage: 1,
        totalPages: 20,
        requestedPort: 0,
      );

      await tester.runAsync(() async {
        await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      });

      // Participant client
      final participantClient = LanParticipantClient(
        sessionId: 'RM-REAL-1',
        deviceId: 'dev_part_real',
        displayName: 'Participant',
        autoReconnect: false,
      );

      await tester.runAsync(() async {
        await participantClient.connect(
          hostAddress: InternetAddress.loopbackIPv4.address,
          port: hostServer.port,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      // Pump Participant PdfReaderScreen with real PDF file
      await tester.pumpWidget(
        MaterialApp(
          home: PdfReaderScreen(
            book: book,
            sessionId: 'RM-REAL-1',
            isHost: false,
            participantClient: participantClient,
            readingProgressRepository: progressRepo,
            deviceService: deviceService,
            sessionRepository: sessionRepo,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Initial synced page 1
      expect(find.text('Synced: Page 1 of 20'), findsOneWidget);

      // Host changes actual PDF page to 5
      await tester.runAsync(() async {
        hostServer.broadcastPageChange(5);
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      // Participant real PDF viewer automatically changes to same page (5)
      expect(find.text('Synced: Page 5 of 20'), findsOneWidget);

      // Verify SQLite reading_progress contains synchronized page (participant persistence)
      final profile = await deviceService.getOrCreateCurrentProfile();
      // Note: PdfReaderScreen uses its own deviceService profile, but we check via progressRepo for participant device
      // The participantClient's pageStream listener in PdfReaderScreen saves progress with its deviceId from profile
      // So we check latest progress for book and profile id
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      final savedProgress = await progressRepo.getLatestBookProgress(book.id, profile.id);
      expect(savedProgress, isNotNull);
      expect(savedProgress!.currentPage, equals(5));

      // Host changes to page 12
      await tester.runAsync(() async {
        hostServer.broadcastPageChange(12);
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(find.text('Synced: Page 12 of 20'), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await participantClient.disconnect();
        participantClient.dispose();
        await hostServer.stop();
        hostServer.dispose();
      });
    });

    testWidgets('Reconnect: Participant receives state_snapshot and real PDF viewer returns to correct page',
        (WidgetTester tester) async {
      final pdfFile = File(p.join(tempDir.path, 'reconnect_real.pdf'));
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 15);

      final book = await bookRepo.createBook(
        id: 'book-reconnect-real',
        title: 'Reconnect Real PDF',
        author: 'Tester',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 15,
        sha256Hash: 'hash-reconnect-real',
      );

      final hostServer = LanHostServer(
        sessionId: 'RM-REAL-RECONNECT',
        hostDeviceId: 'dev_host_re',
        hostDisplayName: 'Host',
        initialPage: 1,
        totalPages: 15,
        requestedPort: 0,
      );

      await tester.runAsync(() async {
        await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      });

      final participantClient = LanParticipantClient(
        sessionId: 'RM-REAL-RECONNECT',
        deviceId: 'dev_part_re',
        displayName: 'Participant',
        autoReconnect: false,
      );

      await tester.runAsync(() async {
        await participantClient.connect(
          hostAddress: InternetAddress.loopbackIPv4.address,
          port: hostServer.port,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PdfReaderScreen(
            book: book,
            sessionId: 'RM-REAL-RECONNECT',
            isHost: false,
            participantClient: participantClient,
            readingProgressRepository: progressRepo,
            deviceService: deviceService,
            sessionRepository: sessionRepo,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text('Synced: Page 1 of 15'), findsOneWidget);

      // Disconnect participant
      await tester.runAsync(() async {
        await participantClient.disconnect();
        await Future.delayed(const Duration(milliseconds: 100));
        // Host moves to page 9 while participant disconnected
        hostServer.broadcastPageChange(9);
        await Future.delayed(const Duration(milliseconds: 50));
      });

      // Reconnect participant - should receive state_snapshot with current page 9
      final snapshotCompleter = Completer<int>();
      final sub = participantClient.pageStream.listen((page) {
        if (!snapshotCompleter.isCompleted) {
          snapshotCompleter.complete(page);
        }
      });

      await tester.runAsync(() async {
        await participantClient.reconnect();
        await Future.delayed(const Duration(milliseconds: 200));
      });

      final restoredPage = await snapshotCompleter.future.timeout(const Duration(seconds: 2));
      expect(restoredPage, equals(9));

      await tester.pumpAndSettle();
      expect(find.text('Synced: Page 9 of 15'), findsOneWidget);

      await sub.cancel();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await participantClient.disconnect();
        participantClient.dispose();
        await hostServer.stop();
        hostServer.dispose();
      });
    });

    testWidgets('Lifecycle: Host Start/Pause/Resume/End propagate to participant real PDF screen',
        (WidgetTester tester) async {
      final pdfFile = File(p.join(tempDir.path, 'lifecycle_real.pdf'));
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 8);

      final book = await bookRepo.createBook(
        id: 'book-lifecycle-real',
        title: 'Lifecycle Real PDF',
        author: 'Tester',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 8,
        sha256Hash: 'hash-lifecycle-real',
      );

      final hostServer = LanHostServer(
        sessionId: 'RM-REAL-LIFECYCLE',
        hostDeviceId: 'dev_host_lc',
        hostDisplayName: 'Host',
        initialPage: 1,
        totalPages: 8,
        requestedPort: 0,
      );

      await tester.runAsync(() async {
        await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      });

      final participantClient = LanParticipantClient(
        sessionId: 'RM-REAL-LIFECYCLE',
        deviceId: 'dev_part_lc',
        displayName: 'Participant',
        autoReconnect: false,
      );

      await tester.runAsync(() async {
        await participantClient.connect(
          hostAddress: InternetAddress.loopbackIPv4.address,
          port: hostServer.port,
        );
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PdfReaderScreen(
            book: book,
            sessionId: 'RM-REAL-LIFECYCLE',
            isHost: false,
            participantClient: participantClient,
            readingProgressRepository: progressRepo,
            deviceService: deviceService,
            sessionRepository: sessionRepo,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      // Start
      await tester.runAsync(() async {
        hostServer.broadcastSessionStarted();
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(participantClient.sessionStatus, equals('active'));

      // Pause
      await tester.runAsync(() async {
        hostServer.broadcastSessionPaused();
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('Reading Session Paused by Host'), findsOneWidget);
      expect(participantClient.sessionStatus, equals('paused'));

      // Resume
      await tester.runAsync(() async {
        hostServer.broadcastSessionResumed();
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(participantClient.sessionStatus, equals('active'));

      // End
      await tester.runAsync(() async {
        hostServer.broadcastSessionEnded();
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.text('Reading Session Ended by Host'), findsOneWidget);
      expect(participantClient.sessionStatus, equals('ended'));

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await participantClient.disconnect();
        participantClient.dispose();
        await hostServer.stop();
        hostServer.dispose();
      });
    });
  });
}
