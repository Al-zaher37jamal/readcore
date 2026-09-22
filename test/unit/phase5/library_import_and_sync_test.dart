import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/pdf_import_pipeline.dart';
import 'package:readmesh/data/storage/pdf_inspector.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/library/pdf_library_screen.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import '../../test_helpers.dart';

void main() {
  group('Phase 5: Library Import UI and Real PDF Sync Tests', () {
    late Directory tempDir;
    late AppDatabase db;
    late BookRepository bookRepo;
    late ReadingProgressRepository progressRepo;
    late SessionRepository sessionRepo;
    late DeviceService deviceService;
    late BookFileManager fileManager;
    late PdfImportPipeline pipeline;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase5_test_');
      db = AppDatabase.memory();
      bookRepo = BookRepositoryImpl(db);
      progressRepo = ReadingProgressRepositoryImpl(db);
      sessionRepo = SessionRepositoryImpl(db);
      final profileRepo = DeviceProfileRepositoryImpl(db);
      deviceService = DeviceService(repository: profileRepo);
      fileManager = BookFileManager(tempDir);
      await fileManager.initialize();
      pipeline = PdfImportPipeline(
        fileManager: fileManager,
        bookRepository: bookRepo,
        diskSpaceChecker: MockDiskSpaceChecker(10 * 1024 * 1024 * 1024),
        pdfInspector: const PdfInspector(),
      );
      await deviceService.getOrCreateCurrentProfile();
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Library import action is visible - Add PDF button exists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [AppLocalizationsDelegate()],
          home: PdfLibraryScreen(
            bookRepository: bookRepo,
            readingProgressRepository: progressRepo,
            pdfImportPipeline: pipeline,
            deviceService: deviceService,
            bookFileManager: fileManager,
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byKey(const Key('add_pdf_file_button_appbar')), findsOneWidget);
      expect(find.byKey(const Key('add_pdf_fab')), findsOneWidget);
      expect(find.byKey(const Key('add_pdf_file_button_empty')), findsOneWidget);
      expect(find.text('إضافة ملف PDF'), findsWidgets);
    });

    test('Import flow: real PDF file can be imported via existing pipeline', () async {
      final sourcePdf = File('${tempDir.path}/real_test.pdf');
      await TestHelpers.createSamplePdfFile(sourcePdf, pageCount: 20);

      final book = await pipeline.importBook(
        sourceFile: sourcePdf,
        title: 'Real PDF Test',
        author: 'Local Import',
      );

      expect(book.title, equals('Real PDF Test'));
      expect(book.pageCount, equals(20));
      expect(book.sha256Hash.isNotEmpty, isTrue);
      expect(await File(book.filePath).exists(), isTrue);

      final books = await bookRepo.getAllBooks();
      expect(books.length, equals(1));
      expect(books.first.id, equals(book.id));
    });

    test('Duplicate handling: friendly duplicate message not raw stack', () async {
      final sourcePdf = File('${tempDir.path}/dup_test.pdf');
      await TestHelpers.createSamplePdfFile(sourcePdf, pageCount: 5);

      await pipeline.importBook(
        sourceFile: sourcePdf,
        title: 'Dup Test',
      );

      final sourcePdf2 = File('${tempDir.path}/dup_test2.pdf');
      await TestHelpers.createSamplePdfFile(sourcePdf2, pageCount: 5);

      try {
        await pipeline.importBook(sourceFile: sourcePdf2, title: 'Dup Test 2');
        fail('Should have thrown DuplicateBookException');
      } catch (e) {
        expect(e.toString(), isNot(contains('StackTrace')));
        expect(e.toString().contains('already exists') || e.toString().contains('SHA-256'), isTrue);
      }

      final books = await bookRepo.getAllBooks();
      expect(books.length, equals(1));
    });

    test('Page synchronization state transition: Host 1→2→5→10 Participant follows', () async {
      final hostServer = LanHostServer(
        sessionId: 'RM-TEST',
        hostDeviceId: 'host1',
        hostDisplayName: 'Host',
        initialPage: 1,
        totalPages: 20,
        requestedPort: 0,
      );
      final participantClient = LanParticipantClient(
        sessionId: 'RM-TEST',
        deviceId: 'part1',
        displayName: 'Participant',
        autoReconnect: false,
      );

      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );

      final receivedPages = <int>[];
      final sub = participantClient.pageStream.listen((page) {
        receivedPages.add(page);
      });

      hostServer.broadcastPageChange(2, 20);
      await Future.delayed(const Duration(milliseconds: 50));
      hostServer.broadcastPageChange(5, 20);
      await Future.delayed(const Duration(milliseconds: 50));
      hostServer.broadcastPageChange(10, 20);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(receivedPages, contains(2));
      expect(receivedPages, contains(5));
      expect(receivedPages, contains(10));
      expect(participantClient.currentPage, equals(10));

      await sub.cancel();
      await participantClient.disconnect();
      participantClient.dispose();
      await hostServer.stop();
      hostServer.dispose();
    });

    testWidgets('PdfReaderScreen participant follows Host page changes visibly',
        (WidgetTester tester) async {
      final pdfFile = File('${tempDir.path}/sync_book.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 20);

      final testBook = await bookRepo.createBook(
        id: 'book-sync-ui',
        title: 'Sync Test Book',
        author: 'Test',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 20,
        sha256Hash: 'hash-sync-ui',
      );

      final hostServer = LanHostServer(
        sessionId: 'RM-SYNC-UI',
        hostDeviceId: 'host-ui',
        hostDisplayName: 'Host UI',
        initialPage: 1,
        totalPages: 20,
        requestedPort: 0,
      );
      final participantClient = LanParticipantClient(
        sessionId: 'RM-SYNC-UI',
        deviceId: 'part-ui',
        displayName: 'Participant UI',
        autoReconnect: false,
      );

      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PdfReaderScreen(
            book: testBook,
            sessionId: 'RM-SYNC-UI',
            isHost: false,
            hostServer: null,
            participantClient: participantClient,
            readingProgressRepository: progressRepo,
            deviceService: deviceService,
            sessionRepository: sessionRepo,
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.textContaining('Page 1 of'), findsWidgets);

      hostServer.broadcastPageChange(5, 20);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.textContaining('Page 5 of'), findsWidgets);

      hostServer.broadcastPageChange(10, 20);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.textContaining('Page 10 of'), findsWidgets);

      await participantClient.disconnect();
      participantClient.dispose();
      await hostServer.stop();
      hostServer.dispose();
    });
  });
}

class MockDiskSpaceChecker implements DiskSpaceChecker {
  final int available;
  MockDiskSpaceChecker(this.available);
  @override
  Future<int> getAvailableDiskSpace(String path) async => available;
}
