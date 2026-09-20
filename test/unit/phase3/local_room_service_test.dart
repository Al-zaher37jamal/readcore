import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/errors/exceptions.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/room/local_room_service.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessionRepo;
  late SessionMemberRepository memberRepo;
  late DeviceProfileRepository profileRepo;
  late DeviceService deviceService;
  late BookRepository bookRepo;
  late LocalRoomService roomService;

  setUp(() async {
    db = AppDatabase.memory();
    sessionRepo = SessionRepositoryImpl(db);
    memberRepo = SessionMemberRepositoryImpl(db);
    profileRepo = DeviceProfileRepositoryImpl(db);
    deviceService = DeviceService(repository: profileRepo);
    bookRepo = BookRepositoryImpl(db);

    await deviceService.getOrCreateCurrentProfile();

    // Create a book for session associations
    await bookRepo.createBook(
      id: 'book-room-1',
      title: 'Distributed Algorithms',
      author: 'Nancy Lynch',
      filePath: '/books/da.pdf',
      fileSize: 2048,
      pageCount: 150,
      sha256Hash: 'hash-da-1',
    );

    roomService = LocalRoomService(
      sessionRepository: sessionRepo,
      sessionMemberRepository: memberRepo,
      deviceService: deviceService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalRoomService Tests', () {
    test('Generates simple and valid session codes (e.g. RM-XXXX)', () {
      final code = roomService.generateSessionCode();
      expect(code, startsWith('RM-'));
      expect(code.length, equals(7)); // "RM-" + 4 digits
    });

    test('Creates room with Host role and status created', () async {
      final session = await roomService.createRoom(
        title: 'Lynch Reading Group',
        bookId: 'book-room-1',
      );

      expect(session.title, equals('Lynch Reading Group'));
      expect(session.status, equals('created'));
      expect(session.bookId, equals('book-room-1'));

      final details = await roomService.getRoomDetails(session.id);
      expect(details, isNotNull);
      expect(details!.isHost, isTrue);
      expect(details.members.length, equals(1));
      expect(details.members.first.role, equals('host'));
      expect(details.members.first.status, equals('active'));
    });

    test('Participant joins an existing room using session code', () async {
      final session = await roomService.createRoom(
        title: 'Math Study Room',
        bookId: 'book-room-1',
      );

      // Join as second device
      final joinedSession = await roomService.joinRoom(
        sessionCode: session.id,
        customDeviceId: 'dev_participant_2',
        customDisplayName: 'Bob Participant',
      );

      expect(joinedSession.id, equals(session.id));

      final details = await roomService.getRoomDetails(session.id);
      expect(details!.members.length, equals(2));

      final participant = details.members.firstWhere((m) => m.deviceId == 'dev_participant_2');
      expect(participant.role, equals('participant'));
      expect(participant.displayName, equals('Bob Participant'));
      expect(participant.status, equals('active'));
    });

    test('Session lifecycle: start, pause, resume, and end status transitions', () async {
      final session = await roomService.createRoom(
        title: 'Status Lifecycle Room',
        bookId: 'book-room-1',
      );

      expect(session.status, equals('created'));

      // 1. Start Session
      await roomService.startSession(session.id);
      var current = await sessionRepo.getSessionById(session.id);
      expect(current?.status, equals('active'));

      // 2. Pause Session
      await roomService.pauseSession(session.id);
      current = await sessionRepo.getSessionById(session.id);
      expect(current?.status, equals('paused'));

      // 3. Resume Session
      await roomService.resumeSession(session.id);
      current = await sessionRepo.getSessionById(session.id);
      expect(current?.status, equals('active'));

      // 4. End Session
      await roomService.endSession(session.id);
      current = await sessionRepo.getSessionById(session.id);
      expect(current?.status, equals('ended'));
    });

    test('Rejects joining non-existent or ended sessions', () async {
      // Non-existent code
      expect(
        () => roomService.joinRoom(sessionCode: 'INVALID-CODE'),
        throwsA(isA<NotFoundException>()),
      );

      // Ended room
      final session = await roomService.createRoom(
        title: 'Ended Session Room',
        bookId: 'book-room-1',
      );
      await roomService.endSession(session.id);

      expect(
        () => roomService.joinRoom(
          sessionCode: session.id,
          customDeviceId: 'dev_late_user',
        ),
        throwsA(isA<DatabaseOperationException>()),
      );
    });

    test('Participant leaves room updates status to left', () async {
      final session = await roomService.createRoom(
        title: 'Leave Room Test',
        bookId: 'book-room-1',
      );

      await roomService.joinRoom(
        sessionCode: session.id,
        customDeviceId: 'dev_user_leave',
        customDisplayName: 'Leaving User',
      );

      await roomService.leaveRoom(session.id, 'dev_user_leave');

      final details = await roomService.getRoomDetails(session.id);
      final member = details!.members.firstWhere((m) => m.deviceId == 'dev_user_leave');
      expect(member.status, equals('left'));
    });
  });
}
