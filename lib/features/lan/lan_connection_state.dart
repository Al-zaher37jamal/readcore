/// Connection lifecycle states for LAN communication between Host and Participant.
enum LanConnectionState {
  /// No active socket connection to the host/peers.
  disconnected,

  /// Actively attempting to establish a TCP socket connection.
  connecting,

  /// Socket connected and handshake completed.
  connected,

  /// Temporary connection loss; actively attempting to re-establish connection.
  reconnecting,
}

extension LanConnectionStateExtension on LanConnectionState {
  String get displayName {
    switch (this) {
      case LanConnectionState.disconnected:
        return 'Disconnected';
      case LanConnectionState.connecting:
        return 'Connecting...';
      case LanConnectionState.connected:
        return 'Connected (LAN)';
      case LanConnectionState.reconnecting:
        return 'Reconnecting...';
    }
  }

  bool get isConnected => this == LanConnectionState.connected;
  bool get isDisconnected => this == LanConnectionState.disconnected;
}
