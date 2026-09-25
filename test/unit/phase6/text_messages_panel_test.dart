import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/text_messages/domain/text_message.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_controller.dart';
import 'package:readmesh/features/text_messages/presentation/text_messages_panel.dart';

class _DeferredTextMessagesController extends TextMessagesController {
  final StreamController<List<TextMessage>> events =
      StreamController<List<TextMessage>>.broadcast();

  _DeferredTextMessagesController(MessageRepository repository)
      : super(repository: repository, sessionId: 'solo_book-ui',
          senderId: 'dev-a', senderName: 'أحمد');

  @override
  Stream<List<TextMessage>> watchPage(int pageNumber) => events.stream;
}

void main() {
  late AppDatabase db;
  late MessageRepository messages;
  late TextMessagesController controller;

  Future<void> settleSqlite(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }

  Widget app(int page, {Widget? pdf}) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Column(children: [
      if (pdf != null) Expanded(child: pdf),
      SizedBox(height: 320, child: TextMessagesPanel(
        sessionId: 'solo_book-ui', pageNumber: page,
        senderId: 'dev-a', senderName: 'أحمد', canSend: true,
        controller: controller,
      )),
    ])),
  );

  setUp(() async {
    db = AppDatabase.memory();
    await BookRepositoryImpl(db).createBook(id: 'book-ui', title: 'Book',
      author: 'Author', filePath: '/tmp/ui.pdf', fileSize: 100,
      pageCount: 309, sha256Hash: 'text-ui-hash');
    await SessionRepositoryImpl(db).createSession(id: 'solo_book-ui',
      title: 'Solo', hostDeviceId: 'dev-a', bookId: 'book-ui',
      status: 'active');
    messages = MessageRepositoryImpl(db);
    controller = TextMessagesController(repository: messages,
      sessionId: 'solo_book-ui', senderId: 'dev-a', senderName: 'أحمد');
  });

  tearDown(() async => db.close());

  testWidgets('send appears immediately; empty rejected; rebuild and page filter',
      (tester) async {
    await tester.pumpWidget(app(8));
    await settleSqlite(tester);
    expect(find.text('الرسائل النصية'), findsOneWidget);
    final send = find.byKey(const Key('send_text_message_button'));
    expect((tester.widget<IconButton>(send).icon as Icon).icon, Icons.mic_none);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    expect(await messages.getPageText('solo_book-ui', 8), isEmpty);
    await tester.enterText(find.byKey(const Key('text_message_input')), '  ');
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('text_message_input')),
      'السلام عليكم');
    expect((tester.widget<IconButton>(send).icon as Icon).icon, Icons.send);
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await settleSqlite(tester);
    expect(find.text('السلام عليكم'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect((await messages.getPageText('solo_book-ui', 8)).single.text,
      'السلام عليكم');
    expect(tester.widget<TextField>(find.byKey(const Key('text_message_input')))
      .controller!.text, isEmpty);

    // Same widget subtree, new page: previous data must not flash on screen.
    await tester.pumpWidget(app(9));
    expect(find.text('السلام عليكم'), findsNothing);
    await settleSqlite(tester);
    expect(find.text('السلام عليكم'), findsNothing);
    await tester.enterText(find.byKey(const Key('text_message_input')),
      'صفحة تسعة');
    await tester.tap(send);
    await settleSqlite(tester);
    expect(find.text('صفحة تسعة'), findsOneWidget);

    await tester.pumpWidget(app(8));
    await settleSqlite(tester);
    expect(find.text('السلام عليكم'), findsOneWidget);
    expect(find.text('صفحة تسعة'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(8)); // panel disposed and created again
    await settleSqlite(tester);
    expect(find.text('السلام عليكم'), findsOneWidget);
  });

  testWidgets('loading, error and retry keep inline composer visible',
      (tester) async {
    final deferred = _DeferredTextMessagesController(messages);
    controller = deferred;
    await tester.pumpWidget(app(8));
    expect(find.byKey(const Key('text_messages_panel')), findsOneWidget);
    expect(find.byKey(const Key('text_message_loading')), findsOneWidget);
    expect(find.byKey(const Key('text_message_input')), findsOneWidget);
    deferred.events.addError(StateError('SQLite unavailable'));
    await settleSqlite(tester);
    expect(find.byKey(const Key('text_message_error')), findsOneWidget);
    expect(find.byKey(const Key('text_message_count')), findsOneWidget);
    expect(find.byKey(const Key('text_message_input')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry_text_messages')));
    await tester.pump();
    expect(find.byKey(const Key('text_message_loading')), findsOneWidget);
    deferred.events.add(const <TextMessage>[]);
    await settleSqlite(tester);
    expect(find.byKey(const Key('text_message_error')), findsNothing);
    expect(find.byKey(const Key('text_message_count')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await deferred.events.close();
  });

  testWidgets('short panel scrolls its error and retry instead of overflowing',
      (tester) async {
    final deferred = _DeferredTextMessagesController(messages);
    controller = deferred;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SizedBox(height: 160, child: TextMessagesPanel(
        sessionId: 'solo_book-ui', pageNumber: 8,
        senderId: 'dev-a', senderName: 'أحمد', canSend: true,
        controller: controller,
      ))),
    ));
    deferred.events.addError(StateError('SQLite unavailable'));
    await settleSqlite(tester);
    expect(find.byKey(const Key('text_message_error')), findsOneWidget);
    expect(find.byKey(const Key('retry_text_messages')), findsOneWidget);
    expect(find.byKey(const Key('text_message_input')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await deferred.events.close();
  });

  testWidgets('missing repository shows an error instead of hiding the panel',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(height: 320, child: TextMessagesPanel(
        sessionId: 'solo_book-ui', pageNumber: 8,
        senderId: 'dev-a', senderName: 'أحمد', canSend: true,
      ))),
    ));
    await settleSqlite(tester);
    expect(find.byKey(const Key('text_messages_panel')), findsOneWidget);
    expect(find.byKey(const Key('text_message_error')), findsOneWidget);
    expect(find.byKey(const Key('text_message_input')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('text_message_input')))
      .enabled, isFalse);
  });

  testWidgets('1000 messages are lazily scrollable; PDF sibling is not rebuilt',
      (tester) async {
    // Preload before mounting to avoid 1000 intermediate stream rebuilds.
    await db.writeTx(() async {
      for (var i = 0; i < 1000; i++) {
        await db.customStatement('''
INSERT INTO messages (id, session_id, page_number, sender_id, sender_name,
  content, message_type, created_at, updated_at, status)
VALUES (?, 'solo_book-ui', 8, 'dev-a', 'أحمد', ?, 'text', ?, ?, 'local')
''', ['bulk_$i', 'message $i', i + 1000, i + 1000]);
      }
    });
    var pdfBuilds = 0;
    await tester.pumpWidget(app(8, pdf: Builder(builder: (_) {
      pdfBuilds++;
      return const ColoredBox(color: Colors.white,
        child: Center(child: Text('PDF sibling')));
    })));
    await settleSqlite(tester);
    expect(find.byKey(const Key('text_message_count')), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    final list = find.byKey(const Key('text_message_list'));
    final scrollable = find.descendant(of: list,
      matching: find.byType(Scrollable));
    expect(scrollable, findsOneWidget);
    final scroll = tester.state<ScrollableState>(scrollable);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(list, const Offset(0, 150));
    await settleSqlite(tester);
    expect(scroll.position.pixels, greaterThan(0));
    final before = pdfBuilds;
    await tester.enterText(find.byKey(const Key('text_message_input')), 'جديدة');
    await tester.tap(find.byKey(const Key('send_text_message_button')));
    await settleSqlite(tester);
    expect(find.text('جديدة'), findsOneWidget);
    expect(find.text('1001'), findsOneWidget);
    expect(pdfBuilds, before);
  });

  testWidgets('edit and delete are available only for local sender', (tester) async {
    await messages.createText(id: 'mine', sessionId: 'solo_book-ui',
      pageNumber: 8, senderId: 'dev-a', senderName: 'أحمد', text: 'قديم');
    await messages.createText(id: 'theirs', sessionId: 'solo_book-ui',
      pageNumber: 8, senderId: 'dev-b', senderName: 'سارة', text: 'آخر');
    await tester.pumpWidget(app(8));
    await settleSqlite(tester);
    expect(find.byKey(const Key('edit_message_mine')), findsOneWidget);
    expect(find.byKey(const Key('delete_message_theirs')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('edit_message_mine')));
    await tester.tap(find.byKey(const Key('edit_message_mine')));
    await tester.enterText(find.byKey(const Key('edit_text_message')), 'جديد');
    await tester.tap(find.byKey(const Key('save_text_message_edit')));
    await settleSqlite(tester);
    expect(find.text('جديد'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete_message_mine')));
    await settleSqlite(tester);
    expect(find.text('جديد'), findsNothing);
    expect(find.text('آخر'), findsOneWidget);
  });
}
