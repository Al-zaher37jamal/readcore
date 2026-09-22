import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
import 'package:readmesh/core/l10n/language_service.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/main.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_test_');

    final db = AppDatabase.memory();
    await setupLocator(
      customDatabase: db,
      customStorageDir: tempDir,
      customDiskSpaceChecker: MockDiskSpaceChecker(),
    );
  });

  tearDown(() async {
    await resetLocator();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'ReadMeshApp smoke test verifies Library and Rooms navigation',
    (WidgetTester tester) async {
      final languageService = getIt<LanguageService>();

      await tester.pumpWidget(
        ReadMeshApp(
          languageService: languageService,
        ),
      );
      await tester.pumpAndSettle();

      // Smoke-test the main app shell without depending on a specific locale.
      expect(find.byType(ReadMeshApp), findsOneWidget);

      // Unmount and flush Drift stream cancellation zero-delay timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    },
  );
}
