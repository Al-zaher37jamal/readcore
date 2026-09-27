import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:readmesh/data/repositories/session_reading_timer_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/features/reading_time/domain/session_reading_timer.dart';

/// Only timer listeners are notified each second. The Reader, PDF viewer,
/// current page and discussion streams are never rebuilt by this ticker.
class SessionReadingTimerController extends ChangeNotifier {
  final SessionReadingTimerRepository repository;
  final SessionRepository sessionRepository;
  final String sessionId;
  final String actorDeviceId;
  final DateTime Function() _now;

  SessionReadingTimerController({
    required this.repository,
    required this.sessionRepository,
    required this.sessionId,
    required this.actorDeviceId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  SessionReadingTimer? _value;
  StreamSubscription<SessionReadingTimer?>? _subscription;
  Timer? _ticker;
  bool _disposed = false;
  bool _busy = false;
  bool _finishing = false;
  bool _isLeader = false;
  Object? _error;

  SessionReadingTimer? get value => _value;
  ReadingTimerStatus get status =>
      _value?.status ?? ReadingTimerStatus.notConfigured;
  bool get isLeader => _isLeader;
  bool get busy => _busy;
  Object? get error => _error;
  int get remainingSeconds => _value?.remainingSeconds(_now()) ?? 0;

  Future<void> load() async {
    final session = await sessionRepository.getSessionById(sessionId);
    if (session == null) throw StateError('Reading session not found');
    if (_disposed) return;
    // Role comes from the persisted session, never from a hidden UI button or
    // the caller's isHost flag. SQLite guards the writes again atomically.
    _isLeader = session.hostDeviceId == actorDeviceId;
    _apply(await repository.get(sessionId));
    if (_disposed) return;
    await _subscription?.cancel();
    _subscription = repository.watch(sessionId).listen(_apply,
      onError: (Object error) {
        if (_disposed) return;
        _error = error;
        notifyListeners();
      });
  }

  Future<void> configure(int durationMinutes) async {
    if (!_isLeader || _disposed) {
      throw StateError('Only the session leader can configure reading time');
    }
    if (durationMinutes < 1 || durationMinutes > 1440) {
      throw RangeError.range(durationMinutes, 1, 1440, 'durationMinutes');
    }
    if (_busy) throw StateError('Reading time change already in progress');
    _busy = true;
    notifyListeners();
    try {
      _apply(await repository.configure(sessionId, actorDeviceId,
          durationMinutes));
      _error = null;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> start() async {
    if (!_isLeader || _disposed) {
      throw StateError('Only the session leader can start reading time');
    }
    if (status != ReadingTimerStatus.configured || _busy) {
      throw StateError('Configure reading time before starting it');
    }
    _busy = true;
    notifyListeners();
    try {
      _apply(await repository.start(sessionId, actorDeviceId));
      _error = null;
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _apply(SessionReadingTimer? value) {
    if (_disposed) return;
    _value = value;
    if (status == ReadingTimerStatus.running) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    notifyListeners();
  }

  /// Public to refresh after foreground resume and to test clock changes
  /// without waiting for wall time. Never changes page, PDF or session status.
  void refresh() {
    if (_disposed || status != ReadingTimerStatus.running) return;
    if (remainingSeconds == 0) {
      if (_finishing) return;
      _finishing = true;
      _ticker?.cancel();
      _ticker = null;
      unawaited(_completeExpiry());
    } else {
      notifyListeners();
    }
  }

  Future<void> _completeExpiry() async {
    try {
      _apply(await repository.finishIfDue(sessionId));
    } catch (error) {
      if (!_disposed) {
        _error = error;
        notifyListeners();
      }
    } finally {
      _finishing = false;
      if (!_disposed && status == ReadingTimerStatus.running) {
        _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => refresh());
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
