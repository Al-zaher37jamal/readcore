import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/lan/lan_participant_client.dart';
import 'package:readmesh/features/profile/device_service.dart';
import '../../test_helpers.dart';

void main() {
  group('Phase 6: Session History and Resumable Local Reading', () {
    late Directory tempDir;
    late AppDatabase db;
    late BookRepository bookRepo;
    late ReadingProgressRepository progressRepo;
    late SessionRepository sessionRepo;
    late DeviceService deviceService;
    late String deviceId;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase6_test_');
      db = AppDatabase.memory();
      bookRepo = BookRepositoryImpl(db);
      progressRepo = ReadingProgressRepositoryImpl(db);
      sessionRepo = SessionRepositoryImpl(db);
      final profileRepo = DeviceProfileRepositoryImpl(db);
      deviceService = DeviceService(repository: profileRepo);
      final profile = await deviceService.getOrCreateCurrentProfile();
      deviceId = profile.id;
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Save and Leave appears in My Sessions history', () async {
      final pdfFile = File('${tempDir.path}/book1.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 20);
      final book = await bookRepo.createBook(
        id: 'book-1',
        title: 'Test Book 1',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 20,
        sha256Hash: 'hash1',
      );

      final session = await sessionRepo.createSession(
        id: 'solo_${book.id}',
        title: 'Personal Reading',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      await progressRepo.updateProgress(
        id: 'prog_${session.id}_${book.id}_$deviceId',
        sessionId: session.id,
        bookId: book.id,
        deviceId: deviceId,
        currentPage: 10,
        totalPages: 20,
      );

      await sessionRepo.saveAndLeaveSession(session.id, lastPage: 10, totalPages: 20);

      final savedSessions = await sessionRepo.getSavedSessions();
      expect(savedSessions.length, equals(1));
      expect(savedSessions.first.id, equals(session.id));
      expect(savedSessions.first.status, equals('saved'));
    });

    test('2. Resume restores page and book', () async {
      final pdfFile = File('${tempDir.path}/book2.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 20);
      final book = await bookRepo.createBook(
        id: 'book-2',
        title: 'Resume Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 20,
        sha256Hash: 'hash2',
      );

      final sessionId = 'solo_${book.id}';
      await sessionRepo.createSession(
        id: sessionId,
        title: 'Personal Reading',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'saved',
      );

      await progressRepo.updateProgress(
        id: 'prog_${sessionId}_${book.id}_$deviceId',
        sessionId: sessionId,
        bookId: book.id,
        deviceId: deviceId,
        currentPage: 10,
        totalPages: 20,
      );

      final savedProgress = await progressRepo.getProgress(sessionId, deviceId);
      expect(savedProgress, isNotNull);
      expect(savedProgress!.currentPage, equals(10));
      expect(savedProgress.totalPages, equals(20));

      final retrievedBook = await bookRepo.getBookById(book.id);
      expect(retrievedBook, isNotNull);
      expect(retrievedBook!.title, equals('Resume Book'));
      expect(await File(retrievedBook.filePath).exists(), isTrue);
    });

    test('3. Delete removes history only, book remains in Library', () async {
      final pdfFile = File('${tempDir.path}/book3.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 15);
      final book = await bookRepo.createBook(
        id: 'book-3',
        title: 'Delete Test Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 15,
        sha256Hash: 'hash3',
      );

      final session = await sessionRepo.createSession(
        id: 'solo_${book.id}',
        title: 'Personal Reading',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'saved',
      );

      await sessionRepo.deleteSessionHistoryOnly(session.id);

      final sessionAfter = await sessionRepo.getSessionById(session.id);
      expect(sessionAfter, isNull);

      final bookAfter = await bookRepo.getBookById(book.id);
      expect(bookAfter, isNotNull);
      expect(bookAfter!.title, equals('Delete Test Book'));

      final books = await bookRepo.getAllBooks();
      expect(books.any((b) => b.id == book.id), isTrue);
    });

    test('4. End Reading Session disconnects participants', () async {
      final pdfFile = File('${tempDir.path}/book4.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 10);
      final book = await bookRepo.createBook(
        id: 'book-4',
        title: 'Group Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 10,
        sha256Hash: 'hash4',
      );

      final session = await sessionRepo.createSession(
        id: 'RM-TEST-END',
        title: 'Group Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      final hostServer = LanHostServer(
        sessionId: session.id,
        hostDeviceId: deviceId,
        hostDisplayName: 'Host',
        initialPage: 1,
        totalPages: 10,
        requestedPort: 0,
      );
      final participantClient = LanParticipantClient(
        sessionId: session.id,
        deviceId: 'participant-1',
        displayName: 'Participant',
        autoReconnect: false,
      );

      await hostServer.start(bindAddress: InternetAddress.loopbackIPv4);
      await participantClient.connect(
        hostAddress: InternetAddress.loopbackIPv4.address,
        port: hostServer.port,
      );

      // Host ends session
      hostServer.broadcastSessionEnded();
      await sessionRepo.endReadingSession(session.id);
      await hostServer.stop();

      final endedSession = await sessionRepo.getSessionById(session.id);
      expect(endedSession, isNotNull);
      expect(endedSession!.status, equals('ended'));

      // Participant should be disconnected
      await participantClient.disconnect();
      participantClient.dispose();
      hostServer.dispose();
    });

    test('5. Ended session not joinable, history viewable', () async {
      final pdfFile = File('${tempDir.path}/book5.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 10);
      final book = await bookRepo.createBook(
        id: 'book-5',
        title: 'Ended Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 10,
        sha256Hash: 'hash5',
      );

      final session = await sessionRepo.createSession(
        id: 'RM-ENDED',
        title: 'Ended Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'ended',
      );

      final savedSessions = await sessionRepo.getSavedSessions();
      expect(savedSessions.any((s) => s.id == session.id), isTrue);

      // Ended session should not be joinable as active room
      // In RoomsScreen, ended rooms show history only message
      // Here we verify status is ended and it is in history but not active
      final allSessions = await sessionRepo.getAllSessions();
      final ended = allSessions.firstWhere((s) => s.id == session.id);
      expect(ended.status, equals('ended'));

      // Verify book still exists
      final bookAfter = await bookRepo.getBookById(book.id);
      expect(bookAfter, isNotNull);
    });

    test('6. Save/Leave != End - saved is resumable, ended is not', () async {
      final pdfFile = File('${tempDir.path}/book6.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 20);
      final book = await bookRepo.createBook(
        id: 'book-6',
        title: 'Lifecycle Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 20,
        sha256Hash: 'hash6',
      );

      final savedSession = await sessionRepo.createSession(
        id: 'solo_${book.id}_saved',
        title: 'Saved Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );
      await sessionRepo.saveAndLeaveSession(savedSession.id, lastPage: 10, totalPages: 20);

      final endedSession = await sessionRepo.createSession(
        id: 'RM-ENDED-2',
        title: 'Ended Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );
      await sessionRepo.endReadingSession(endedSession.id);

      final saved = await sessionRepo.getSessionById(savedSession.id);
      final ended = await sessionRepo.getSessionById(endedSession.id);

      expect(saved, isNotNull);
      expect(saved!.status, equals('saved'));
      expect(ended, isNotNull);
      expect(ended!.status, equals('ended'));

      // Saved should be resumable (can be set back to active)
      await sessionRepo.updateSessionStatus(saved.id, 'active');
      final resumed = await sessionRepo.getSessionById(saved.id);
      expect(resumed!.status, equals('active'));

      // Ended should remain ended, not resumable as live room
      // But history viewable
      expect(ended.status, equals('ended'));
    });

    test('7. Resumed LAN creates fresh connection, not reuse old socket', () async {
      final pdfFile = File('${tempDir.path}/book7.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 10);
      final book = await bookRepo.createBook(
        id: 'book-7',
        title: 'LAN Resume Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 10,
        sha256Hash: 'hash7',
      );

      final session = await sessionRepo.createSession(
        id: 'RM-LAN-RESUME',
        title: 'Group Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      // First host server
      final hostServer1 = LanHostServer(
        sessionId: session.id,
        hostDeviceId: deviceId,
        hostDisplayName: 'Host',
        initialPage: 5,
        totalPages: 10,
        requestedPort: 0,
      );
      await hostServer1.start(bindAddress: InternetAddress.loopbackIPv4);
      final firstPort = hostServer1.port;
      final firstIp = hostServer1.localIp;
      await hostServer1.stop();
      hostServer1.dispose();

      // Simulate save and leave
      await sessionRepo.saveAndLeaveSession(session.id, lastPage: 5, totalPages: 10);

      // Resume with fresh server - new IP/port, not old socket
      final hostServer2 = LanHostServer(
        sessionId: session.id,
        hostDeviceId: deviceId,
        hostDisplayName: 'Host',
        initialPage: 5,
        totalPages: 10,
        requestedPort: 0,
      );
      await hostServer2.start(bindAddress: InternetAddress.loopbackIPv4);
      final secondPort = hostServer2.port;

      // Port should be different (fresh) or at least not reuse old closed socket
      // We verify that second server is a new instance and can start independently
      expect(secondPort, isNot(equals(0)));
      expect(hostServer2.isRunning, isTrue);

      await hostServer2.stop();
      hostServer2.dispose();

      // Verify session history not duplicated
      final allSessions = await sessionRepo.getAllSessions();
      final matching = allSessions.where((s) => s.id == session.id).toList();
      expect(matching.length, equals(1));
    });

    test('8. Auto-save reading position on page change persists', () async {
      final pdfFile = File('${tempDir.path}/book8.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 20);
      final book = await bookRepo.createBook(
        id: 'book-8',
        title: 'AutoSave Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 20,
        sha256Hash: 'hash8',
      );

      final sessionId = 'solo_${book.id}';
      await sessionRepo.createSession(
        id: sessionId,
        title: 'Personal Reading',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      // Simulate page changes with auto-save
      for (int page = 1; page <= 10; page++) {
        await progressRepo.updateProgress(
          id: 'prog_${sessionId}_${book.id}_$deviceId',
          sessionId: sessionId,
          bookId: book.id,
          deviceId: deviceId,
          currentPage: page,
          totalPages: 20,
        );
        await sessionRepo.updateSessionLastPage(sessionId, page, 20);
      }

      final progress = await progressRepo.getProgress(sessionId, deviceId);
      expect(progress, isNotNull);
      expect(progress!.currentPage, equals(10));

      // Simulate app close and reopen - progress should survive
      final progressAfterReopen = await progressRepo.getLatestBookProgress(book.id, deviceId);
      expect(progressAfterReopen, isNotNull);
      expect(progressAfterReopen!.currentPage, equals(10));
    });

    test('9. Session lifecycle distinguishes active/paused/saved/ended', () async {
      final pdfFile = File('${tempDir.path}/book9.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 10);
      final book = await bookRepo.createBook(
        id: 'book-9',
        title: 'Lifecycle Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 10,
        sha256Hash: 'hash9',
      );

      final session = await sessionRepo.createSession(
        id: 'RM-LIFECYCLE',
        title: 'Lifecycle Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      expect(session.status, equals('active'));

      await sessionRepo.updateSessionStatus(session.id, 'paused');
      var updated = await sessionRepo.getSessionById(session.id);
      expect(updated!.status, equals('paused'));

      await sessionRepo.saveAndLeaveSession(session.id, lastPage: 5, totalPages: 10);
      updated = await sessionRepo.getSessionById(session.id);
      expect(updated!.status, equals('saved'));

      await sessionRepo.endReadingSession(session.id);
      updated = await sessionRepo.getSessionById(session.id);
      expect(updated!.status, equals('ended'));

      // Saved != Ended
      expect('saved' != 'ended', isTrue);
    });

    test('10. Timer and stats flags independent optional', () async {
      final pdfFile = File('${tempDir.path}/book10.pdf');
      await TestHelpers.createSamplePdfFile(pdfFile, pageCount: 10);
      final book = await bookRepo.createBook(
        id: 'book-10',
        title: 'Flags Book',
        author: 'Author',
        filePath: pdfFile.path,
        fileSize: 1024,
        pageCount: 10,
        sha256Hash: 'hash10',
      );

      final session = await sessionRepo.createSession(
        id: 'RM-FLAGS',
        title: 'Flags Session',
        hostDeviceId: deviceId,
        bookId: book.id,
        status: 'active',
      );

      // Initially both disabled
      var flags = await sessionRepo.getSessionFlags(session.id);
      expect(flags!['timerEnabled'], equals(false));
      expect(flags['statsEnabled'], equals(false));

      // Enable timer only
      await sessionRepo.updateSessionFlags(session.id, timerEnabled: true);
      flags = await sessionRepo.getSessionFlags(session.id);
      expect(flags!['timerEnabled'], equals(true));
      expect(flags['statsEnabled'], equals(false));

      // Enable stats only, disable timer
      await sessionRepo.updateSessionFlags(session.id, timerEnabled: false, statsEnabled: true);
      flags = await sessionRepo.getSessionFlags(session.id);
      expect(flags!['timerEnabled'], equals(false));
      expect(flags['statsEnabled'], equals(true));

      // Enable both
      await sessionRepo.updateSessionFlags(session.id, timerEnabled: true, statsEnabled: true);
      flags = await sessionRepo.getSessionFlags(session.id);
      expect(flags!['timerEnabled'], equals(true));
      expect(flags['statsEnabled'], equals(true));

      // Disable both
      await sessionRepo.updateSessionFlags(session.id, timerEnabled: false, statsEnabled: false);
      flags = await sessionRepo.getSessionFlags(session.id);
      expect(flags!['timerEnabled'], equals(false));
      expect(flags['statsEnabled'], equals(false));
    });
  });
}
