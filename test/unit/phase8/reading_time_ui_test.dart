import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/l10n/app_localizations.dart';
import 'package:readmesh/core/theme/app_theme.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_reading_timer_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/reading_time/domain/session_reading_timer.dart';
import 'package:readmesh/features/reading_time/presentation/reading_time_widgets.dart';
import 'package:readmesh/features/reading_time/presentation/session_reading_timer_controller.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late SessionReadingTimerRepository timers;
  late ValueNotifier<int> elapsedNotifier;
  var now = DateTime.utc(2026, 9, 26, 12);
  const sessionId = 'RM-TIMER-UI';

  Widget harness(SessionReadingTimerController controller, {
      String language = 'ar', Stream<List<SessionMember>>? members}) =>
      MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SafeArea(child: SingleChildScrollView(
          child: Column(children: [
            ReaderSessionInfoBar(timer: controller,
              members: members ?? const Stream<List<SessionMember>>.empty(),
              hostDeviceId: 'leader', isGroup: true),
            ReaderToolsSection(timer: controller, canEditSession: true,
              elapsedEnabled: false, elapsedSeconds: elapsedNotifier,
              statsEnabled: false, onOptionSelected: (_) {}),
          ]),
        ))),
      );

  Future<void> waitFor(WidgetTester tester, bool Function() ready,
      String step) async {
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < const Duration(seconds: 4)) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 35)));
      await tester.pump();
      final exception = tester.takeException();
      if (exception != null) fail('$step threw: $exception');
      if (ready()) return;
    }
    fail('Timed out waiting for $step');
  }

  setUp(() async {
    now = DateTime.utc(2026, 9, 26, 12);
    db = AppDatabase.memory();
    elapsedNotifier = ValueNotifier<int>(0);
    sessions = SessionRepositoryImpl(db);
    timers = SessionReadingTimerRepositoryImpl(db, now: () => now);
    await BookRepositoryImpl(db).createBook(id: 'ui-book', title: 'Book',
      author: 'Local', filePath: '/tmp/reading-timer-ui.pdf', fileSize: 100,
      pageCount: 10, sha256Hash: 'phase8-ui');
    await sessions.createSession(id: sessionId, title: 'Group',
      hostDeviceId: 'leader', bookId: 'ui-book', status: 'active');
  });

  tearDown(() async {
    elapsedNotifier.dispose();
    await db.close();
  });

  test('Reader and discussion use the same calm light palette', () {
    expect(AppTheme.backgroundColor, const Color(0xFFF7F9FC));
    expect(AppTheme.surfaceColor, const Color(0xFFFFFFFF));
    expect(AppTheme.primaryColor, const Color(0xFF2563EB));
    expect(AppTheme.softBlue, const Color(0xFFEAF2FF));
    expect(AppTheme.softSky, const Color(0xFFF3F8FF));
    expect(AppTheme.borderColor, const Color(0xFFDCE3EC));
    expect(AppTheme.textPrimaryColor, const Color(0xFF1F2937));
    expect(AppTheme.textSecondaryColor, const Color(0xFF6B7280));
  });

  testWidgets('leader opens settings, chooses 30, starts and sees the countdown',
      (tester) async {
    final controller = SessionReadingTimerController(repository: timers,
      sessionRepository: sessions, sessionId: sessionId,
      actorDeviceId: 'leader', now: () => now);
    addTearDown(controller.dispose);
    await controller.load();
    final members = SessionMemberRepositoryImpl(db);
    for (final device in ['leader', 'guest-a', 'guest-b']) {
      await members.addMember(id: 'member_$device', sessionId: sessionId,
        deviceId: device, displayName: device,
        role: device == 'leader' ? 'host' : 'participant', status: 'active');
    }
    await tester.pumpWidget(harness(controller,
      members: members.watchMembersBySessionId(sessionId)));
    await waitFor(tester,
      () => tester.widget<Text>(find.byKey(
          const Key('reader_participant_count'))).data == '3',
      'active participant count');
    expect(find.text('لا يوجد وقت محدد'), findsWidgets);
    await tester.tap(find.byKey(const Key('reader_tools_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('reading_time_settings_entry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reading_time_settings_entry')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ReadingTimeSettingsSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('reading_time_option_30')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reading_time_save')));
    await waitFor(tester,
      () => controller.status == ReadingTimerStatus.configured,
      'Configured after Save');
    expect(controller.value!.durationMinutes, 30);
    await tester.pump(const Duration(milliseconds: 350));
    final start = find.byKey(const Key('start_reading_timer'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await waitFor(tester, () => controller.status == ReadingTimerStatus.running,
      'Running after Start');
    expect(tester.widget<Text>(find.byKey(const Key('reading_time_status')))
        .data, '30:00');
    now = now.add(const Duration(seconds: 18));
    controller.refresh();
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('reading_time_status')))
        .data, '29:42');
    now = now.add(const Duration(minutes: 26));
    controller.refresh();
    await tester.pump();
    expect((tester.widget<Container>(find.byKey(
        const Key('reading_time_badge'))).decoration as BoxDecoration).color,
        const Color(0xFFFFF7E6));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose(); // No periodic timer may survive this widget test.
  });

  testWidgets('participant reads persisted duration, has no settings or start',
      (tester) async {
    await timers.configure(sessionId, 'leader', 30);
    final controller = SessionReadingTimerController(repository: timers,
      sessionRepository: sessions, sessionId: sessionId,
      actorDeviceId: 'participant', now: () => now);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(harness(controller, language: 'en'));
    expect(tester.widget<Text>(find.byKey(const Key('reading_time_status')))
        .data, '30 minutes');
    await timers.start(sessionId, 'leader');
    await waitFor(tester, () => controller.status == ReadingTimerStatus.running,
        'participant sees current countdown');
    expect(tester.widget<Text>(find.byKey(const Key('reading_time_status')))
        .data, '30:00');
    await tester.tap(find.byKey(const Key('reader_tools_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('reading_time_settings_entry')), findsOneWidget);
    expect(find.byKey(const Key('start_reading_timer')), findsNothing);
    expect(find.byKey(const Key('reader_timer_stats_menu')), findsNothing);
    expect(tester.widget<ListTile>(find.byKey(
        const Key('reading_time_settings_entry'))).onTap, isNull);
    expect(find.byType(ReadingTimeSettingsSheet), findsNothing);
    await expectLater(controller.configure(15), throwsStateError);
    await expectLater(controller.start(), throwsStateError);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('custom duration validates and handles RTL, small/large, keyboard',
      (tester) async {
    final controller = SessionReadingTimerController(repository: timers,
      sessionRepository: sessions, sessionId: sessionId,
      actorDeviceId: 'leader', now: () => now);
    addTearDown(controller.dispose);
    await controller.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(harness(controller));
    await tester.tap(find.byKey(const Key('reader_tools_toggle')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reading_time_settings_entry')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('reading_time_custom_option')));
    await tester.pump();
    final input = find.byKey(const Key('reading_time_custom_minutes'));
    expect(Directionality.of(tester.element(input)), TextDirection.rtl);
    for (final invalid in ['0', '1441', 'abc', '']) {
      await tester.enterText(input, invalid);
      await tester.tap(find.byKey(const Key('reading_time_save')));
      await tester.pump();
      expect(find.byKey(const Key('reading_time_validation_error')),
          findsOneWidget);
      expect(controller.status, ReadingTimerStatus.notConfigured);
    }
    // Short viewport approximates the on-screen keyboard: sheet scrolls,
    // composer/header keep their layout rather than overflowing.
    tester.view.physicalSize = const Size(320, 350);
    await tester.pump();
    await tester.ensureVisible(input);
    await tester.enterText(input, '75');
    await tester.ensureVisible(find.byKey(const Key('reading_time_save')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('reading_time_save')));
    await waitFor(tester, () => controller.status == ReadingTimerStatus.configured,
        '75-minute custom duration');
    expect(controller.value!.durationMinutes, 75);
    await tester.pump(const Duration(milliseconds: 350));
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pump();
    expect(find.byKey(const Key('reader_tools_section')), findsOneWidget);
    expect(find.byKey(const Key('reading_time_badge')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
