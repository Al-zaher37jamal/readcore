import 'dart:async';

/// Ensures that only one write operation or write transaction
/// can execute on SQLite at any given time.
/// This implements the Single-Writer Strategy for ReadMesh,
/// preventing SQLITE_BUSY lock contentions and ensuring
/// deterministic write ordering.
class SingleWriterLock {
  Future<void>? _lastWrite;

  /// Executes [action] strictly after any previously queued write completes.
  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _lastWrite;
    final completer = Completer<void>();
    _lastWrite = completer.future;

    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // Ignore previous errors so subsequent writes are not permanently blocked
      }
    }

    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// Whether there is currently a write operation waiting or executing
  bool get hasActiveWrites => _lastWrite != null;
}
