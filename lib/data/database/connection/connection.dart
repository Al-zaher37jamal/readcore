import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:readmesh/core/constants/app_constants.dart';

/// Opens a persistent SQLite connection backed by the file system.
LazyDatabase openConnection([File? customDbFile]) {
  return LazyDatabase(() async {
    final dbFile = customDbFile ?? await getDefaultDatabaseFile();
    return NativeDatabase.createInBackground(
      dbFile,
      setup: (database) {
        // Basic low-level SQLite setup if needed
      },
    );
  });
}

/// Creates an in-memory database connection for unit testing.
DatabaseConnection createInMemoryDatabaseConnection() {
  return DatabaseConnection(
    NativeDatabase.memory(),
  );
}

/// Resolves the default database file path in the app's document directory.
Future<File> getDefaultDatabaseFile() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, AppConstants.databaseName));
  return file;
}
