import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/room/local_room_service.dart';
import 'package:readmesh/features/room/room_detail_screen.dart';
import 'package:readmesh/features/room/rooms_screen.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessionRepo;
  late SessionMemberRepository memberRepo;
  late DeviceProfileRepository profileRepo;
  late DeviceService deviceService;
  late BookRepository bookRepo;
  late LocalRoomService roomService;
  late Book testBook;

  setUp(() async {
    db = AppDatabase.memory();
    sessionRepo = SessionRepositoryImpl(db);
    memberRepo = SessionMemberRepositoryImpl(db);
    profileRepo = DeviceProfileRepositoryImpl(db);
    deviceService = DeviceService(repository: profileRepo);
    bookRepo = BookRepositoryImpl(db);

    await deviceService.getOrCreateCurrentProfile();

    testBook = await bookRepo.createBook(
      id: 'book-room-ui-1',
      title: 'Operating Systems Principles',
      author: 'Silberschatz',
      filePath: '/books/os.pdf',
      fileSize: 4096,
      pageCount: 80,
      sha256Hash: 'hash-os-1',
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

  testWidgets('RoomsScreen renders empty state when no rooms exist', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoomsScreen(
          roomService: roomService,
          sessionRepository: sessionRepo,
          bookRepository: bookRepo,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('No Active Reading Rooms'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets('RoomsScreen renders room cards when rooms exist', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await roomService.createRoom(
        title: 'OS Study Group',
        bookId: testBook.id,
        customSessionCode: 'RM-7788',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RoomsScreen(
          roomService: roomService,
          sessionRepository: sessionRepo,
          bookRepository: bookRepo,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('OS Study Group'), findsOneWidget);
    expect(find.text('RM-7788'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets('RoomDetailScreen displays room details and updates status lifecycle',
      (WidgetTester tester) async {
    late Session session;
    await tester.runAsync(() async {
      session = await roomService.createRoom(
        title: 'OS Study Group',
        bookId: testBook.id,
        customSessionCode: 'RM-7788',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RoomDetailScreen(
          sessionId: session.id,
          roomService: roomService,
          bookRepository: bookRepo,
          deviceService: deviceService,
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify Room Code and Host status displayed
    expect(find.byKey(const Key('room_code_display')), findsOneWidget);
    expect(find.text('RM-7788'), findsOneWidget);
    expect(find.text('You are Host'), findsOneWidget);

    // Verify Start Session button is visible
    final startBtnFinder = find.byKey(const Key('start_session_button'));
    expect(startBtnFinder, findsOneWidget);

    // Tap Start Session -> Status becomes active
    await tester.tap(startBtnFinder);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('pause_session_button')), findsOneWidget);
    expect(find.byKey(const Key('end_session_button')), findsOneWidget);

    // Verify participant list contains the host
    final profile = await deviceService.getOrCreateCurrentProfile();
    expect(find.text(profile.displayName), findsOneWidget);

    // Tap Pause Session -> Status becomes paused
    final pauseBtnFinder = find.byKey(const Key('pause_session_button'));
    await tester.tap(pauseBtnFinder);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('resume_session_button')), findsOneWidget);

    // Tap Resume Session -> Status becomes active
    final resumeBtnFinder = find.byKey(const Key('resume_session_button'));
    await tester.tap(resumeBtnFinder);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const Key('pause_session_button')), findsOneWidget);

    // Tap End Session -> Status becomes ended
    final endBtnFinder = find.byKey(const Key('end_session_button'));
    await tester.tap(endBtnFinder);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 2));

    // Verify room status displays ended
    expect(find.text('ENDED'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
