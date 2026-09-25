/// A persisted, page-specific local text message. `status == 'local'` means
/// SQLite has committed the message; it does not imply network delivery.
class TextMessage {
  final String id;
  final String sessionId;
  final int pageNumber;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  /// SQLite insertion order, shared with audio rows in the same table.
  final int? localOrder;

  const TextMessage({
    required this.id,
    required this.sessionId,
    required this.pageNumber,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.localOrder,
  });

  factory TextMessage.fromRow(Map<String, dynamic> row) {
    final created = row['created_at'] as int;
    final updated = row['updated_at'] as int? ?? created;
    return TextMessage(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      pageNumber: row['page_number'] as int,
      senderId: row['sender_id'] as String,
      senderName: row['sender_name'] as String,
      text: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(created * 1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated * 1000, isUtc: true),
      status: row['status'] as String,
      localOrder: row['local_order'] as int?,
    );
  }
}
