/// A committed, local audio message in the existing `messages` table.
/// The file itself lives in the app's private documents directory, not SQLite.
class AudioMessage {
  final String id;
  final String sessionId;
  final int pageNumber;
  final String senderId;
  final String senderDisplayName;
  final String audioPath;
  final int durationMs;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String? sha256;
  final int? bytes;
  /// SQLite insertion order across text and audio on this page.
  final int? localOrder;

  const AudioMessage({
    required this.id,
    required this.sessionId,
    required this.pageNumber,
    required this.senderId,
    required this.senderDisplayName,
    required this.audioPath,
    required this.durationMs,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.sha256,
    this.bytes,
    this.localOrder,
  });

  factory AudioMessage.fromRow(Map<String, dynamic> row) {
    final created = row['created_at'] as int;
    final updated = row['updated_at'] as int? ?? created;
    return AudioMessage(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      pageNumber: row['page_number'] as int,
      senderId: row['sender_id'] as String,
      senderDisplayName: row['sender_name'] as String,
      audioPath: row['voice_path'] as String,
      durationMs: row['duration_ms'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created * 1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated * 1000, isUtc: true),
      status: row['status'] as String,
      sha256: row['voice_sha256'] as String?,
      bytes: row['voice_bytes'] as int?,
      localOrder: row['local_order'] as int?,
    );
  }
}
