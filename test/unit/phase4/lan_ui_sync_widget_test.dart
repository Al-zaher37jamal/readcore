import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import '../../test_helpers.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late BookRepository bookRepo;
  late ReadingProgressRepository progressRepo;
  late SessionRepository sessionRepo;
  late DeviceService deviceService;
  late Book testBook;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lan_widget_test_');
    db = AppDatabase.memory();
    bookRepo = BookRepositoryImpl(db);
    progressRepo = ReadingProgressRepositoryImpl(db);
    sessionRepo = SessionRepositoryImpl(db);
    final profileRepo = DeviceProfileRepositoryImpl(db);
    deviceService = DeviceService(repository: profileRepo);

    await deviceService.getOrCreateCurrentProfile();

    final pdfFile = File('${tempDir.path}/sync_book.pdf');
    await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 5);

    testBook = await bookRepo.createBook(
      id: 'book-sync-ui',
      title: 'LAN Synchronization Guide',
      author: 'Distributed Team',
      filePath: pdfFile.path,
      fileSize: 1024,
      pageCount: 5,
      sha256Hash: 'hash-sync-ui',
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('PdfReaderScreen in Host mode broadcasts page turn to HostServer',
      (WidgetTester tester) async {
    final hostServer = LanHostServer(
      sessionId: 'RM-HOST-WIDGET',
      hostDeviceId: 'dev_host',
      hostDisplayName: 'Host',
      initialPage: 1,
      totalPages: 5,
      requestedPort: 0,
    );

    await tester.runAsync(() async {
      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PdfReaderScreen(
          book: testBook,
          sessionId: 'RM-HOST-WIDGET',
          isHost: true,
          hostServer: hostServer,
          readingProgressRepository: progressRepo,
          deviceService: deviceService,
          sessionRepository: sessionRepo,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify Title and initial Page 1
    expect(find.text('LAN Synchronization Guide'), findsWidgets);
    expect(find.text('Page 1 of 5'), findsWidgets);

    // Host taps next page button
    final nextBtn = find.byKey(const Key('next_page_button'));
    await tester.tap(nextBtn);

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Verify host server state updated to page 2
    expect(hostServer.currentPage, equals(2));
    expect(find.text('Page 2 of 5'), findsWidgets);

    // Clean up
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(() async {
      await hostServer.stop();
      hostServer.dispose();
    });
  });

  testWidgets('PdfReaderScreen in Participant mode follows page & status updates and disables manual navigation',
      (WidgetTester tester) async {
    final participantClient = LanParticipantClient(
      sessionId: 'RM-PART-WIDGET',
      deviceId: 'dev_part',
      displayName: 'Participant',
      autoReconnect: false,
    );

    late ServerSocket server;
    late Socket clientSocket;

    await tester.runAsync(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((sock) {
        clientSocket = sock;
      });

      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );
      await Future.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PdfReaderScreen(
          book: testBook,
          sessionId: 'RM-PART-WIDGET',
          isHost: false,
          participantClient: participantClient,
          readingProgressRepository: progressRepo,
          deviceService: deviceService,
          sessionRepository: sessionRepo,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify Participant UI: manual next/prev buttons are disabled
    final nextBtn = tester.widget<IconButton>(find.byKey(const Key('next_page_button')));
    final prevBtn = tester.widget<IconButton>(find.byKey(const Key('prev_page_button')));
    expect(nextBtn.onPressed, isNull);
    expect(prevBtn.onPressed, isNull);

    // Verify Synced text is visible
    expect(find.text('Synced: Page 1 of 5'), findsOneWidget);

    // Simulate Host turning to page 4 and pausing session over socket
    await tester.runAsync(() async {
      clientSocket.write('{"type":"pageChanged","sessionId":"RM-PART-WIDGET","senderDeviceId":"dev_h","currentPage":4,"totalPages":5}\n');
      clientSocket.write('{"type":"sessionPaused","sessionId":"RM-PART-WIDGET","senderDeviceId":"dev_h"}\n');
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify participant screen flipped to page 4 automatically!
    expect(find.text('Synced: Page 4 of 5'), findsOneWidget);

    // Verify session paused alert banner appeared
    expect(find.text('Reading Session Paused by Host'), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(() async {
      await participantClient.disconnect();
      participantClient.dispose();
      await server.close();
    });
  });
}
