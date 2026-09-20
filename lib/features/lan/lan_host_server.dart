import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'lan_message.dart';

/// Information about a connected participant on the Host's TCP server.
class LanConnectedParticipant {
  final String deviceId;
  final String displayName;
  final String remoteAddress;
  final int remotePort;
  final int joinedAt;

  const LanConnectedParticipant({
    required this.deviceId,
    required this.displayName,
    required this.remoteAddress,
    required this.remotePort,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'displayName': displayName,
        'remoteAddress': remoteAddress,
        'remotePort': remotePort,
        'joinedAt': joinedAt,
      };
}

/// TCP Server run on the Host device that coordinates reading synchronization.
/// The Host is authoritative for page turns, session state, and participant roster.
class LanHostServer {
  final String sessionId;
  final String hostDeviceId;
  final String hostDisplayName;
  final int requestedPort;

  ServerSocket? _serverSocket;
  int _actualPort = 0;
  String _localIp = '127.0.0.1';

  // Authoritative state
  int _currentPage;
  int _totalPages;
  String _sessionStatus;

  // Active connected client sockets mapped by socket
  final Map<Socket, LanConnectedParticipant> _clients = {};

  final StreamController<LanMessage> _messageController =
      StreamController<LanMessage>.broadcast();
  final StreamController<List<LanConnectedParticipant>> _participantsController =
      StreamController<List<LanConnectedParticipant>>.broadcast();

  bool _isRunning = false;

  LanHostServer({
    required this.sessionId,
    required this.hostDeviceId,
    required this.hostDisplayName,
    int? initialPage,
    int? totalPages,
    String? sessionStatus,
    this.requestedPort = 40404,
  })  : _currentPage = initialPage ?? 1,
        _totalPages = totalPages ?? 1,
        _sessionStatus = sessionStatus ?? 'created';

  bool get isRunning => _isRunning;
  int get port => _actualPort;
  String get localIp => _localIp;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String get sessionStatus => _sessionStatus;
  int get connectedClientCount => _clients.length;
  List<LanConnectedParticipant> get participants => _clients.values.toList();

  Stream<LanMessage> get messageStream => _messageController.stream;
  Stream<List<LanConnectedParticipant>> get participantsStream =>
      _participantsController.stream;

  /// Helper to discover the local device's IPv4 LAN address (non-loopback).
  static Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// Starts the TCP server socket.
  Future<void> start({InternetAddress? bindAddress}) async {
    if (_isRunning) return;

    _localIp = await getLocalIpAddress();
    final address = bindAddress ?? InternetAddress.anyIPv4;

    _serverSocket = await ServerSocket.bind(address, requestedPort);
    _actualPort = _serverSocket!.port;
    _isRunning = true;

    _serverSocket!.listen(
      _handleClientConnection,
      onError: (err) {
        stop();
      },
      onDone: () {
        stop();
      },
    );
  }

  /// Handles a new incoming TCP connection from a participant.
  void _handleClientConnection(Socket clientSocket) {
    // Decode incoming bytes into UTF-8 strings, and split on newlines
    final lineStream = utf8.decoder
        .bind(clientSocket)
        .transform(const LineSplitter());

    final sub = lineStream.listen(
      (line) => _processClientLine(clientSocket, line),
      onError: (_) => _disconnectClient(clientSocket),
      onDone: () => _disconnectClient(clientSocket),
      cancelOnError: true,
    );

    // If socket disconnects, cancel subscription
    clientSocket.done.then((_) {
      sub.cancel();
      _disconnectClient(clientSocket);
    }).catchError((_) {
      sub.cancel();
      _disconnectClient(clientSocket);
    });
  }

  /// Processes a single newline-delimited JSON line received from a participant.
  void _processClientLine(Socket clientSocket, String line) {
    try {
      final msg = LanMessage.deserialize(line);
      _messageController.add(msg);

      switch (msg.type) {
        case LanMessageType.join:
          _handleJoin(clientSocket, msg);
          break;
        case LanMessageType.leave:
          _disconnectClient(clientSocket);
          break;
        case LanMessageType.ping:
          _sendToClient(
            clientSocket,
            LanMessage.pong(
              sessionId: sessionId,
              deviceId: hostDeviceId,
            ),
          );
          break;
        default:
          // Other message types ignored from participant (Host is authoritative)
          break;
      }
    } catch (_) {
      // Ignore malformed packet lines
    }
  }

  /// Handles participant handshake: registers participant, sends JOIN_ACK and STATE_SNAPSHOT.
  void _handleJoin(Socket clientSocket, LanMessage msg) {
    final participant = LanConnectedParticipant(
      deviceId: msg.senderDeviceId,
      displayName: msg.senderName ?? 'Participant',
      remoteAddress: clientSocket.remoteAddress.address,
      remotePort: clientSocket.remotePort,
      joinedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _clients[clientSocket] = participant;
    _notifyParticipantsChanged();

    // 1. Send JOIN_ACK to the newly connected participant
    _sendToClient(
      clientSocket,
      LanMessage.joinAck(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        hostDisplayName: hostDisplayName,
      ),
    );

    // 2. Send authoritative STATE_SNAPSHOT immediately
    _sendToClient(
      clientSocket,
      LanMessage.stateSnapshot(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        currentPage: _currentPage,
        totalPages: _totalPages,
        sessionStatus: _sessionStatus,
        participants: _clients.values.map((p) => p.toJson()).toList(),
      ),
    );
  }

  /// Safely sends a message to a specific client socket.
  void _sendToClient(Socket clientSocket, LanMessage msg) {
    try {
      clientSocket.write(msg.serialize());
    } catch (_) {
      _disconnectClient(clientSocket);
    }
  }

  /// Broadcasts a message to all connected participant sockets.
  void broadcast(LanMessage message) {
    final line = message.serialize();
    final deadSockets = <Socket>[];

    for (final socket in _clients.keys) {
      try {
        socket.write(line);
      } catch (_) {
        deadSockets.add(socket);
      }
    }

    for (final dead in deadSockets) {
      _disconnectClient(dead);
    }
  }

  /// Authoritative: Host turned the page. Updates internal state and broadcasts to all participants.
  void broadcastPageChange(int newPage, [int? totalPages]) {
    _currentPage = newPage;
    if (totalPages != null) _totalPages = totalPages;

    broadcast(
      LanMessage.pageChanged(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        currentPage: _currentPage,
        totalPages: _totalPages,
      ),
    );
  }

  /// Authoritative: Host started session.
  void broadcastSessionStarted() {
    _sessionStatus = 'active';
    broadcast(
      LanMessage.sessionStarted(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        currentPage: _currentPage,
      ),
    );
  }

  /// Authoritative: Host paused session.
  void broadcastSessionPaused() {
    _sessionStatus = 'paused';
    broadcast(
      LanMessage.sessionPaused(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        currentPage: _currentPage,
      ),
    );
  }

  /// Authoritative: Host resumed session.
  void broadcastSessionResumed() {
    _sessionStatus = 'active';
    broadcast(
      LanMessage.sessionResumed(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        currentPage: _currentPage,
      ),
    );
  }

  /// Authoritative: Host ended session.
  void broadcastSessionEnded() {
    _sessionStatus = 'ended';
    broadcast(
      LanMessage.sessionEnded(
        sessionId: sessionId,
        hostDeviceId: hostDeviceId,
        currentPage: _currentPage,
      ),
    );
  }

  void _disconnectClient(Socket socket) {
    if (_clients.containsKey(socket)) {
      _clients.remove(socket);
      _notifyParticipantsChanged();
    }
    try {
      socket.destroy();
    } catch (_) {}
  }

  void _notifyParticipantsChanged() {
    if (!_participantsController.isClosed) {
      _participantsController.add(participants);
    }
  }

  /// Closes all participant connections, closes server socket, and releases resources.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    for (final socket in _clients.keys.toList()) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _clients.clear();

    try {
      await _serverSocket?.close();
    } catch (_) {}
    _serverSocket = null;

    _notifyParticipantsChanged();
  }

  /// Fully disposes controllers.
  void dispose() {
    stop();
    _messageController.close();
    _participantsController.close();
  }
}
