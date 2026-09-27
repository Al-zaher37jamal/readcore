/// A session-wide countdown, distinct from the existing per-device elapsed
/// reading statistics in participant_reading_time.
enum ReadingTimerStatus { notConfigured, configured, running, finished }

class SessionReadingTimer {
  final String sessionId;
  final int? durationMinutes;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final String? configuredByLeaderId;
  final ReadingTimerStatus status;

  const SessionReadingTimer({
    required this.sessionId,
    required this.durationMinutes,
    required this.startedAt,
    required this.endsAt,
    required this.configuredByLeaderId,
    required this.status,
  });

  int remainingSeconds(DateTime now) {
    final duration = (durationMinutes ?? 0) * 60;
    if (status == ReadingTimerStatus.configured) return duration;
    if (status != ReadingTimerStatus.running || endsAt == null) return 0;
    // Ceiling prevents the clock from displaying 29:59 immediately after a
    // 30-minute timer starts. The deadline, not a tick counter, is authoritative.
    final millis = endsAt!.difference(now.toUtc()).inMilliseconds;
    return ((millis + 999) ~/ 1000).clamp(0, duration).toInt();
  }
}
