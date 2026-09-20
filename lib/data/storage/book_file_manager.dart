import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:readmesh/core/constants/app_constants.dart';

/// Manages local physical files and directories for books, cache, and temporary imports.
class BookFileManager {
  final Directory? _injectedRootDir;

  BookFileManager([this._injectedRootDir]);

  Directory? _rootDir;
  Directory? _booksDir;
  Directory? _cacheDir;
  Directory? _tempDir;

  /// Initializes the storage directories on disk.
  Future<void> initialize() async {
    if (_injectedRootDir != null) {
      _rootDir = _injectedRootDir;
    } else {
      _rootDir = await getApplicationDocumentsDirectory();
    }

    _booksDir = Directory(p.join(_rootDir!.path, AppConstants.booksDirectoryName));
    _cacheDir = Directory(p.join(_rootDir!.path, AppConstants.cacheDirectoryName));
    _tempDir = Directory(p.join(_rootDir!.path, 'temp'));

    await ensureDirectoriesExist();
  }

  /// Ensures that all managed directories exist.
  Future<void> ensureDirectoriesExist() async {
    if (_booksDir == null) await initialize();
    if (!await _booksDir!.exists()) await _booksDir!.create(recursive: true);
    if (!await _cacheDir!.exists()) await _cacheDir!.create(recursive: true);
    if (!await _tempDir!.exists()) await _tempDir!.create(recursive: true);
  }

  Directory get rootDir => _rootDir!;
  Directory get booksDir => _booksDir!;
  Directory get cacheDir => _cacheDir!;
  Directory get tempDir => _tempDir!;

  /// Returns the canonical local file path for a book with [bookId].
  String getBookFilePath(String bookId) {
    return p.join(booksDir.path, '$bookId.pdf');
  }

  /// Returns a temporary file path inside the temp directory.
  String getTempFilePath(String fileName) {
    return p.join(tempDir.path, fileName);
  }

  /// Returns a cache file path inside the cache directory.
  String getCacheFilePath(String fileName) {
    return p.join(cacheDir.path, fileName);
  }

  /// Checks if a file exists at the given path.
  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Safely deletes a file if it exists.
  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      // Ignore errors if already deleted
    }
    return false;
  }

  /// Returns the file size in bytes, or 0 if the file doesn't exist.
  Future<int> getFileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Lists all files in the books directory.
  Future<List<File>> listBookFiles() async {
    await ensureDirectoriesExist();
    return _listFiles(booksDir);
  }

  /// Lists all files in the cache directory.
  Future<List<File>> listCacheFiles() async {
    await ensureDirectoriesExist();
    return _listFiles(cacheDir);
  }

  /// Lists all files in the temp directory.
  Future<List<File>> listTempFiles() async {
    await ensureDirectoriesExist();
    return _listFiles(tempDir);
  }

  /// Cleans up any leftover temporary files.
  Future<int> clearTempDirectory() async {
    await ensureDirectoriesExist();
    final files = await listTempFiles();
    int count = 0;
    for (final file in files) {
      try {
        await file.delete();
        count++;
      } catch (_) {}
    }
    return count;
  }

  Future<List<File>> _listFiles(Directory dir) async {
    final list = <File>[];
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          list.add(entity);
        }
      }
    }
    return list;
  }
}
