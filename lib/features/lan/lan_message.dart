import 'dart:convert';

/// Types of LAN messages exchanged between Host and Participants.
enum LanMessageType {
  /// Participant requests to join a room session.
  join,

  /// Host acknowledges the join request.
  joinAck,

  /// Host provides authoritative state (page, status, participants).
  stateSnapshot,

  /// Host navigated to a new page.
  pageChanged,

  /// Host started the reading session.
  sessionStarted,

  /// Host paused the reading session.
  sessionPaused,

  /// Host resumed the reading session.
  sessionResumed,

  /// Host ended the reading session.
  sessionEnded,

  /// Participant intentionally left the room.
  leave,

  /// Heartbeat ping to check connection liveness.
  ping,

  /// Heartbeat pong reply.
  pong,
}

/// Educational LAN message packet sent as newline-delimited JSON over TCP.
class LanMessage {
  final LanMessageType type;
  final String sessionId;
  final String senderDeviceId;
  final String? senderName;
  final int? currentPage;
  final int? totalPages;
  final String? sessionStatus;
  final Map<String, dynamic>? payload;
  final int timestamp;

  LanMessage({
    required this.type,
    required this.sessionId,
    required this.senderDeviceId,
    this.senderName,
    this.currentPage,
    this.totalPages,
    this.sessionStatus,
    this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Creates a JOIN message (Participant -> Host).
  factory LanMessage.join({
    required String sessionId,
    required String deviceId,
    required String displayName,
  }) {
    return LanMessage(
      type: LanMessageType.join,
      sessionId: sessionId,
      senderDeviceId: deviceId,
      senderName: displayName,
    );
  }

  /// Creates a JOIN_ACK message (Host -> Participant).
  factory LanMessage.joinAck({
    required String sessionId,
    required String hostDeviceId,
    String? hostDisplayName,
    Map<String, dynamic>? payload,
  }) {
    return LanMessage(
      type: LanMessageType.joinAck,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      senderName: hostDisplayName,
      payload: payload,
    );
  }

  /// Creates a STATE_SNAPSHOT message (Host -> Participant).
  factory LanMessage.stateSnapshot({
    required String sessionId,
    required String hostDeviceId,
    required int currentPage,
    required int totalPages,
    required String sessionStatus,
    List<Map<String, dynamic>>? participants,
  }) {
    return LanMessage(
      type: LanMessageType.stateSnapshot,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      currentPage: currentPage,
      totalPages: totalPages,
      sessionStatus: sessionStatus,
      payload: participants != null ? {'participants': participants} : null,
    );
  }

  /// Creates a PAGE_CHANGED message (Host -> Participants).
  factory LanMessage.pageChanged({
    required String sessionId,
    required String hostDeviceId,
    required int currentPage,
    int? totalPages,
  }) {
    return LanMessage(
      type: LanMessageType.pageChanged,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  /// Creates a SESSION_STARTED message (Host -> Participants).
  factory LanMessage.sessionStarted({
    required String sessionId,
    required String hostDeviceId,
    int? currentPage,
  }) {
    return LanMessage(
      type: LanMessageType.sessionStarted,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      currentPage: currentPage,
      sessionStatus: 'active',
    );
  }

  /// Creates a SESSION_PAUSED message (Host -> Participants).
  factory LanMessage.sessionPaused({
    required String sessionId,
    required String hostDeviceId,
    int? currentPage,
  }) {
    return LanMessage(
      type: LanMessageType.sessionPaused,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      currentPage: currentPage,
      sessionStatus: 'paused',
    );
  }

  /// Creates a SESSION_RESUMED message (Host -> Participants).
  factory LanMessage.sessionResumed({
    required String sessionId,
    required String hostDeviceId,
    int? currentPage,
  }) {
    return LanMessage(
      type: LanMessageType.sessionResumed,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      currentPage: currentPage,
      sessionStatus: 'active',
    );
  }

  /// Creates a SESSION_ENDED message (Host -> Participants).
  factory LanMessage.sessionEnded({
    required String sessionId,
    required String hostDeviceId,
    int? currentPage,
  }) {
    return LanMessage(
      type: LanMessageType.sessionEnded,
      sessionId: sessionId,
      senderDeviceId: hostDeviceId,
      currentPage: currentPage,
      sessionStatus: 'ended',
    );
  }

  /// Creates a LEAVE message (Participant -> Host).
  factory LanMessage.leave({
    required String sessionId,
    required String deviceId,
    String? displayName,
  }) {
    return LanMessage(
      type: LanMessageType.leave,
      sessionId: sessionId,
      senderDeviceId: deviceId,
      senderName: displayName,
    );
  }

  /// Creates a PING heartbeat message.
  factory LanMessage.ping({
    required String sessionId,
    required String deviceId,
  }) {
    return LanMessage(
      type: LanMessageType.ping,
      sessionId: sessionId,
      senderDeviceId: deviceId,
    );
  }

  /// Creates a PONG heartbeat response.
  factory LanMessage.pong({
    required String sessionId,
    required String deviceId,
  }) {
    return LanMessage(
      type: LanMessageType.pong,
      sessionId: sessionId,
      senderDeviceId: deviceId,
    );
  }

  /// Serializes the message to a Map.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'sessionId': sessionId,
      'senderDeviceId': senderDeviceId,
      if (senderName != null) 'senderName': senderName,
      if (currentPage != null) 'currentPage': currentPage,
      if (totalPages != null) 'totalPages': totalPages,
      if (sessionStatus != null) 'sessionStatus': sessionStatus,
      if (payload != null) 'payload': payload,
      'timestamp': timestamp,
    };
  }

  /// Deserializes a message from a Map.
  factory LanMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'ping';
    final type = LanMessageType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => LanMessageType.ping,
    );

    return LanMessage(
      type: type,
      sessionId: json['sessionId'] as String? ?? '',
      senderDeviceId: json['senderDeviceId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      currentPage: json['currentPage'] as int?,
      totalPages: json['totalPages'] as int?,
      sessionStatus: json['sessionStatus'] as String?,
      payload: json['payload'] != null ? Map<String, dynamic>.from(json['payload'] as Map) : null,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Serializes this message to a single-line JSON string terminated by newline `\n`.
  String serialize() {
    return '${jsonEncode(toJson())}\n';
  }

  /// Deserializes a raw JSON string line into a [LanMessage].
  static LanMessage deserialize(String rawLine) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty LAN message line');
    }
    final jsonMap = jsonDecode(trimmed) as Map<String, dynamic>;
    return LanMessage.fromJson(jsonMap);
  }

  @override
  String toString() {
    return 'LanMessage(type: ${type.name}, sessionId: $sessionId, sender: $senderDeviceId, page: $currentPage, status: $sessionStatus)';
  }
}
