import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/core/di/injection.dart';
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

  testWidgets('ReadMeshApp smoke test verifies Library and Rooms navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ReadMeshApp());
    await tester.pumpAndSettle();

    expect(find.text('My PDF Library'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);

    // Unmount and flush Drift stream cancellation zero-delay timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
