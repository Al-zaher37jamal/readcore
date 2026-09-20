class AppConstants {
  static const String appName = 'ReadMesh';
  static const String appVersion = '1.0.0';

  // Database constants
  static const String databaseName = 'readmesh.db';
  static const int databaseVersion = 1;

  // File and Storage limits
  static const int maxPdfSizeBytes = 300 * 1024 * 1024; // 300 MB
  static const int maxPdfPages = 10000; // ~10,000 pages
  static const int minDiskSpaceBufferBytes = 50 * 1024 * 1024; // 50 MB safety margin

  // Storage directories
  static const String booksDirectoryName = 'books';
  static const String cacheDirectoryName = 'cache';
}
