import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/core/widgets/app_icon.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/library/pdf_library_screen.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';
import 'package:readmesh/features/lan/lan_host_server.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/reader/pdf_page_view.dart';
import 'package:readmesh/features/reader/pdf_reader_screen.dart';
import 'package:readmesh/features/room/room_detail_screen.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_panel.dart';

import '../../test_helpers.dart';

// Exercise the real RoomDetail navigation without emitting discovery packets.
class _NoBeaconDiscoveryService extends LanDiscoveryService {
  @override
  Future<void> startBeacon({required String sessionId, required String title,
    required String hostIp, required int port,
    int discoveryPort = LanDiscoveryService.defaultDiscoveryPort}) async {}

  @override
  void stopBeacon() {}
}

void main() {
  late Directory root;
  late Book book;

  Widget app(Widget home) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [AppLocalizationsDelegate()],
    home: home,
  );

  Future<void> waitForDatabase(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 120)));
    await tester.pump();
  }

  void expectInlineMessages(WidgetTester tester) {
    final panel = find.byType(TextMessagesPanel);
    expect(panel, findsOneWidget);
    expect(find.byType(PdfPageView), findsOneWidget);
    expect(find.byKey(const Key('page_number_display')), findsOneWidget);
    expect(find.byKey(const Key('text_messages_header')), findsOneWidget);
    expect(find.byKey(const Key('text_message_input')), findsOneWidget);
    expect(find.byKey(const Key('send_text_message_button')), findsOneWidget);
    expect(find.byKey(const Key('reader_notes_discussion')), findsNothing);
    expect(find.byKey(const Key('reader_highlight')), findsNothing);
    final scaffold = tester.widget<Scaffold>(
      find.ancestor(of: panel, matching: find.byType(Scaffold)).first);
    expect(scaffold.body, isA<LayoutBuilder>());
    final scroll = find.byKey(const Key('reader_vertical_scroll'));
    expect(tester.widget<SingleChildScrollView>(scroll), isNotNull);
    expect(find.ancestor(of: panel, matching: scroll), findsOneWidget);
    expect(scaffold.bottomNavigationBar, isNull);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('phase6_reader_wiring_');
    await setupLocator(customDatabase: AppDatabase.memory(),
      customStorageDir: root);
    final pdf = await TestHelpers.createSamplePdfFile(
      File('${root.path}/book.pdf'), pageCount: 12);
    book = await getIt<BookRepository>().createBook(
      id: 'inline-text-book', title: 'Real PDF', author: 'Local',
      filePath: pdf.path, fileSize: await pdf.length(),
      pageCount: 12, sha256Hash: 'inline-text-book-hash');
  });

  tearDown(() async {
    await resetLocator();
    await root.delete(recursive: true);
  });

  testWidgets('Library Read Now opens Solo Reader with inline messages; send and page filter do not reload PDF',
      (tester) async {
    await tester.pumpWidget(app(const PdfLibraryScreen()));
    await waitForDatabase(tester);
    final open = find.byKey(const Key('read_now_book_inline-text-book'));
    expect(open, findsOneWidget);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pump();
    await waitForDatabase(tester);
    expect(find.byType(PdfReaderScreen), findsOneWidget);
    expectInlineMessages(tester);
    final send = find.byKey(const Key('send_text_message_button'));
    expect((tester.widget<IconButton>(send).icon as Icon).icon, Icons.mic_none);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    for (var page = 2; page <= 8; page++) {
      await tester.tap(find.byKey(const Key('next_page_button')));
      await tester.pump();
    }
    final pdfBeforeSend = tester.state(find.byType(PdfPageView));
    await tester.enterText(find.byKey(const Key('text_message_input')),
      'السلام عليكم');
    expect((tester.widget<IconButton>(send).icon as Icon).icon, Icons.send);
    await tester.tap(send);
    await waitForDatabase(tester);
    expect(find.text('السلام عليكم'), findsOneWidget);
    expect((await getIt<MessageRepository>().getPageText(
      'solo_inline-text-book', 8)).single.text, 'السلام عليكم');
    expect(identical(pdfBeforeSend, tester.state(find.byType(PdfPageView))),
      isTrue, reason: 'A new message must not recreate the pdfx viewer');
    expect(tester.widget<TextField>(find.byKey(const Key('text_message_input')))
      .controller!.text, isEmpty);

    await tester.tap(find.byKey(const Key('next_page_button')));
    await tester.pump();
    expect(find.text('السلام عليكم'), findsNothing);
    await waitForDatabase(tester);
    expect(find.text('السلام عليكم'), findsNothing);
    await tester.tap(find.byKey(const Key('prev_page_button')));
    await tester.pump();
    await waitForDatabase(tester);
    expect(find.text('السلام عليكم'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('small portrait, short landscape and RTL keep both panes bounded',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(), GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl, child: child!),
      home: PdfReaderScreen(book: book),
    ));
    await waitForDatabase(tester);
    expectInlineMessages(tester);
    expect(find.text('الرسائل النصية'), findsOneWidget);
    expect((tester.widget<IconButton>(find.byKey(
      const Key('prev_page_button'))).icon as AppIcon).type,
      AppIconType.forward);
    expect((tester.widget<IconButton>(find.byKey(
      const Key('next_page_button'))).icon as AppIcon).type,
      AppIconType.back);
    final viewer = tester.state(find.byType(PdfPageView));
    final readerScrollable = find.descendant(
      of: find.byKey(const Key('reader_vertical_scroll')),
      matching: find.byType(Scrollable),
    ).first;
    final scroll = tester.state<ScrollableState>(readerScrollable);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byKey(const Key('page_number_display')),
      const Offset(0, -220));
    await tester.pump();
    expect(scroll.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);

    // Resize the same mounted Reader as when rotating or showing the keyboard.
    tester.view.physicalSize = const Size(568, 320);
    await tester.pump();
    expectInlineMessages(tester);
    expect(tester.getSize(find.byType(PdfPageView)).height,
      inInclusiveRange(159.0, 161.0));
    expect(identical(viewer, tester.state(find.byType(PdfPageView))), isTrue);
    await tester.ensureVisible(find.byKey(const Key('text_message_input')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(420, 900);
    await tester.pump();
    expectInlineMessages(tester);
    expect(identical(viewer, tester.state(find.byType(PdfPageView))), isTrue);
    expect(tester.takeException(), isNull);

    // A short viewport with the same width approximates IME resize; the
    // composer must still be reachable without remounting the PDF.
    tester.view.physicalSize = const Size(420, 350);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('text_message_input')));
    await tester.pump();
    expect(identical(viewer, tester.state(find.byType(PdfPageView))), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('short PDF error area stays scrollable without overflow',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      height: 160,
      child: PdfPageView(filePath: '${root.path}/missing.pdf',
        pageNumber: 1, totalPages: 1, bookTitle: 'Missing PDF'),
    ))));
    await tester.pump();
    expect(find.textContaining('PDF file not found'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Room Detail opens the same inline Group Reader', (tester) async {
    const sessionId = 'RM-TEXT-ROOM-ROUTE';
    final profile = await getIt<DeviceService>().getOrCreateCurrentProfile();
    await getIt<SessionRepository>().createSession(id: sessionId,
      title: 'Room', hostDeviceId: profile.id, bookId: book.id,
      status: 'active');
    final host = LanHostServer(sessionId: sessionId,
      hostDeviceId: profile.id, hostDisplayName: profile.displayName,
      initialPage: 1, totalPages: book.pageCount,
      sessionStatus: 'active', requestedPort: 0);
    final discovery = _NoBeaconDiscoveryService();
    try {
      await tester.runAsync(() => host.start(
        bindAddress: InternetAddress.loopbackIPv4).timeout(
          const Duration(seconds: 3)));
      await tester.pumpWidget(app(RoomDetailScreen(
        sessionId: sessionId, hostServer: host, discoveryService: discovery,
      )));
      await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 250)));
      await tester.pump();
      final open = find.byKey(const Key('open_room_book_button'));
      expect(open, findsOneWidget);
      await tester.ensureVisible(open);
      expect(tester.widget<ElevatedButton>(open).onPressed, isNotNull);
      await tester.tap(open);
      await tester.pump();
      await waitForDatabase(tester);
      expect(find.byType(PdfReaderScreen), findsOneWidget);
      expectInlineMessages(tester);
      expect(tester.widget<TextMessagesPanel>(find.byType(TextMessagesPanel))
        .sessionId, sessionId);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      discovery.dispose();
      await tester.runAsync(host.stop);
      host.dispose();
    }
  });

  testWidgets('Reader still renders the inline panel if message DI is missing',
      (tester) async {
    await getIt.unregister<MessageRepository>();
    await tester.pumpWidget(app(PdfReaderScreen(book: book)));
    await waitForDatabase(tester);
    expectInlineMessages(tester);
    await waitForDatabase(tester);
    expect(find.byKey(const Key('text_message_error')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(
      const Key('send_text_message_button'))).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Group Reader without contentSync also shows text panel instead of legacy modal',
      (tester) async {
    await getIt<SessionRepository>().createSession(id: 'RM-TEXT-GROUP',
      title: 'Room', hostDeviceId: 'host-a', bookId: book.id,
      status: 'active');
    await tester.pumpWidget(app(PdfReaderScreen(
      book: book, sessionId: 'RM-TEXT-GROUP', isHost: true,
    )));
    await waitForDatabase(tester);
    expectInlineMessages(tester);
    await tester.enterText(find.byKey(const Key('text_message_input')),
      'رسالة محلية');
    await tester.tap(find.byKey(const Key('send_text_message_button')));
    await waitForDatabase(tester);
    expect((await getIt<MessageRepository>().getPageText(
      'RM-TEXT-GROUP', 1)).single.text, 'رسالة محلية');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
