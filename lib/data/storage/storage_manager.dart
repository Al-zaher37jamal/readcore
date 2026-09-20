import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:readmesh/core/constants/app_constants.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';

/// Data model representing local storage utilization across ReadMesh categories.
/// Explicitly contains ONLY: Books, Cache, Database, Total, Available (No Audio).
class StorageUsageReport {
  final int books;
  final int cache;
  final int database;
  final int total;
  final int available;

  const StorageUsageReport({
    required this.books,
    required this.cache,
    required this.database,
    required this.total,
    required this.available,
  });

  String get booksFormatted => formatBytes(books);
  String get cacheFormatted => formatBytes(cache);
  String get databaseFormatted => formatBytes(database);
  String get totalFormatted => formatBytes(total);
  String get availableFormatted => formatBytes(available);

  Map<String, dynamic> toMap() => {
        'books': books,
        'cache': cache,
        'database': database,
        'total': total,
        'available': available,
      };

  @override
  String toString() {
    return 'StorageUsageReport(books: $booksFormatted, cache: $cacheFormatted, '
        'database: $databaseFormatted, total: $totalFormatted, available: $availableFormatted)';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(d < 10 ? 1 : 0)} ${suffixes[i]}';
  }
}

/// Manages and reports on local disk storage usage for ReadMesh.
class StorageManager {
  final BookFileManager _fileManager;
  final DiskSpaceChecker _diskSpaceChecker;
  final File? _customDatabaseFile;

  StorageManager({
    required BookFileManager fileManager,
    DiskSpaceChecker? diskSpaceChecker,
    File? customDatabaseFile,
  })  : _fileManager = fileManager,
        _diskSpaceChecker = diskSpaceChecker ?? const SystemDiskSpaceChecker(),
        _customDatabaseFile = customDatabaseFile;

  /// Generates a comprehensive storage usage report.
  Future<StorageUsageReport> getStorageUsage() async {
    await _fileManager.ensureDirectoriesExist();

    final booksBytes = await _calculateDirectoryBytes(_fileManager.booksDir);
    final cacheBytes = await _calculateDirectoryBytes(_fileManager.cacheDir);
    final databaseBytes = await _calculateDatabaseBytes();
    final totalBytes = booksBytes + cacheBytes + databaseBytes;
    final availableBytes = await _diskSpaceChecker.getAvailableDiskSpace(
      _fileManager.rootDir.path,
    );

    return StorageUsageReport(
      books: booksBytes,
      cache: cacheBytes,
      database: databaseBytes,
      total: totalBytes,
      available: availableBytes,
    );
  }

  /// Clears all files inside the cache directory.
  Future<int> clearCache() async {
    await _fileManager.ensureDirectoriesExist();
    final files = await _fileManager.listCacheFiles();
    int deleted = 0;
    for (final file in files) {
      try {
        await file.delete();
        deleted++;
      } catch (_) {}
    }
    return deleted;
  }

  Future<int> _calculateDirectoryBytes(Directory dir) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<int> _calculateDatabaseBytes() async {
    int total = 0;
    final baseFile = _customDatabaseFile ??
        File(p.join(_fileManager.rootDir.path, AppConstants.databaseName));

    if (await baseFile.exists()) {
      final candidates = [
        baseFile,
        File('${baseFile.path}-wal'),
        File('${baseFile.path}-shm'),
        File('${baseFile.path}-journal'),
      ];
      for (final file in candidates) {
        try {
          if (await file.exists()) {
            total += await file.length();
          }
        } catch (_) {}
      }
    } else if (await _fileManager.rootDir.exists()) {
      // Fallback: search for any .db files in the storage root directory
      await for (final entity in _fileManager.rootDir.list(recursive: false)) {
        if (entity is File && entity.path.endsWith('.db')) {
          try {
            total += await entity.length();
            final wal = File('${entity.path}-wal');
            if (await wal.exists()) total += await wal.length();
            final shm = File('${entity.path}-shm');
            if (await shm.exists()) total += await shm.length();
          } catch (_) {}
        }
      }
    }
    return total;
  }
}
