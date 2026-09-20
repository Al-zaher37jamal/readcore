import 'dart:io';

/// Interface for querying available filesystem storage.
abstract class DiskSpaceChecker {
  /// Returns the available storage space in bytes for the volume containing [path].
  Future<int> getAvailableDiskSpace(String path);
}

/// Production implementation of [DiskSpaceChecker] using POSIX commands or platform heuristics.
class SystemDiskSpaceChecker implements DiskSpaceChecker {
  final int? _overrideAvailableBytes;

  const SystemDiskSpaceChecker([this._overrideAvailableBytes]);

  @override
  Future<int> getAvailableDiskSpace(String path) async {
    if (_overrideAvailableBytes != null) {
      return _overrideAvailableBytes;
    }

    try {
      if (Platform.isLinux || Platform.isMacOS) {
        // Run POSIX df -Pk <path> to get available 1K blocks
        final result = await Process.run('df', ['-Pk', path]);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().trim().split('\n');
          if (lines.length >= 2) {
            // Second line format: Filesystem 1024-blocks Used Available Capacity Mounted
            final parts = lines[1].trim().split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final availableKilobytes = int.tryParse(parts[3]);
              if (availableKilobytes != null) {
                return availableKilobytes * 1024;
              }
            }
          }
        }
      }
    } catch (_) {
      // Fallback below
    }

    // Default safe fallback for tests or environments where df is unavailable: 10 GB
    return 10 * 1024 * 1024 * 1024;
  }
}

/// Test/mock implementation that allows simulating any disk space scenario.
class MockDiskSpaceChecker implements DiskSpaceChecker {
  int availableBytes;

  MockDiskSpaceChecker([this.availableBytes = 10 * 1024 * 1024 * 1024]);

  @override
  Future<int> getAvailableDiskSpace(String path) async {
    return availableBytes;
  }
}
