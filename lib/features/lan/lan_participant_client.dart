import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'lan_connection_state.dart';
import 'lan_message.dart';

/// TCP Client run on Participant devices to receive reading synchronization from the Host.
/// The participant cannot modify the synchronized page; it faithfully reflects the Host's state.
class LanParticipantClient {
  final String sessionId;
  final String deviceId;
  final String displayName;

  Socket? _socket;
  StreamSubscription<String>? _lineSubscription;

  LanConnectionState _state = LanConnectionState.disconnected;

  // Authoritative state received from the Host
  int _currentPage = 1;
  int _totalPages = 1;
  String _sessionStatus = 'created';
  bool _hasSnapshot = false;
  bool _hasJoinAck = false;

  // Last connection parameters for reconnecting
  String? _lastHostAddress;
  int? _lastPort;

  Timer? _reconnectTimer;
  final bool _autoReconnect;
  bool _intentionallyDisconnected = false;
  bool _disposed = false;
  int _connectionGeneration = 0;

  final StreamController<LanConnectionState> _stateController =
      StreamController<LanConnectionState>.broadcast();
  final StreamController<LanMessage> _messageController =
      StreamController<LanMessage>.broadcast();
  final StreamController<int> _pageController =
      StreamController<int>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  LanParticipantClient({
    required this.sessionId,
    required this.deviceId,
    required this.displayName,
    bool autoReconnect = true,
  }) : _autoReconnect = autoReconnect;

  LanConnectionState get state => _state;
  bool get isConnected => _state == LanConnectionState.connected;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  String get sessionStatus => _sessionStatus;
  bool get hasSnapshot => _hasSnapshot;
  bool get hasJoinAck => _hasJoinAck;
  bool get isJoined => isConnected && _hasJoinAck && _hasSnapshot &&
      _sessionStatus != 'saved' && _sessionStatus != 'ended';

  Stream<LanConnectionState> get stateStream => _stateController.stream;
  Stream<LanMessage> get messageStream => _messageController.stream;
  Stream<int> get pageStream => _pageController.stream;
  Stream<String> get statusStream => _statusController.stream;

  /// Connects to the Host's TCP server and performs the join handshake.
  Future<void> connect({
    required String hostAddress,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_disposed) throw StateError('LAN client is disposed.');
    final generation = ++_connectionGeneration;
    _cleanupSocket();
    _lastHostAddress = hostAddress;
    _lastPort = port;
    _intentionallyDisconnected = false;
    _hasSnapshot = false;
    _hasJoinAck = false;

    _updateState(LanConnectionState.connecting);

    try {
      final socket = await Socket.connect(hostAddress, port, timeout: timeout);
      if (_disposed || generation != _connectionGeneration) {
        socket.destroy();
        return;
      }
      _socket = socket;

      _updateState(LanConnectionState.connected);

      // Listen to line-delimited JSON stream
      final lineStream = utf8.decoder
          .bind(socket)
          .transform(const LineSplitter());

      _lineSubscription = lineStream.listen(
        _processHostLine,
        onError: (err) => _handleSocketDisconnect(socket),
        onDone: () => _handleSocketDisconnect(socket),
        cancelOnError: true,
      );

      // Perform the join handshake
      send(
        LanMessage.join(
          sessionId: sessionId,
          deviceId: deviceId,
          displayName: displayName,
        ),
      );
    } catch (e) {
      if (!_disposed && generation == _connectionGeneration) {
        _handleSocketDisconnect();
      }
      rethrow;
    }
  }

  /// Sends a newline-delimited JSON message to the Host.
  void send(LanMessage message) {
    if (_socket != null && _state == LanConnectionState.connected) {
      try {
        _socket!.write(message.serialize());
      } catch (_) {
        _handleSocketDisconnect();
      }
    }
  }

  /// Sends an ordered content/voice packet without buffering the full file in
  /// the OS socket. The regular send() remains unchanged for Phase 4 packets.
  Future<bool> sendAndFlush(LanMessage message) async {
    final socket = _socket;
    if (!isJoined || socket == null || message.sessionId != sessionId) return false;
    try {
      socket.write(message.serialize());
      await socket.flush().timeout(const Duration(seconds: 5));
      return identical(_socket, socket) && isJoined;
    } catch (_) {
      _handleSocketDisconnect(socket);
      return false;
    }
  }

  /// Processes a single line received from the Host.
  void _processHostLine(String line) {
    if (_disposed || line.length > 65536) return;
    try {
      final msg = LanMessage.deserialize(line);
      if (msg.sessionId != sessionId) return;
      _messageController.add(msg);

      switch (msg.type) {
        case LanMessageType.stateSnapshot:
          _hasSnapshot = true;
          if (msg.totalPages != null) {
            _totalPages = msg.totalPages!;
          }
          if (msg.currentPage != null) {
            _currentPage = msg.currentPage!;
            _pageController.add(_currentPage);
          }
          if (msg.sessionStatus != null) {
            _sessionStatus = msg.sessionStatus!;
            _statusController.add(_sessionStatus);
          }
          break;

        case LanMessageType.pageChanged:
          if (msg.totalPages != null) {
            _totalPages = msg.totalPages!;
          }
          if (msg.currentPage != null) {
            _currentPage = msg.currentPage!;
            _pageController.add(_currentPage);
          }
          break;

        case LanMessageType.sessionStarted:
          _sessionStatus = 'active';
          _statusController.add(_sessionStatus);
          if (msg.currentPage != null) {
            _currentPage = msg.currentPage!;
            _pageController.add(_currentPage);
          }
          break;

        case LanMessageType.sessionPaused:
          _sessionStatus = 'paused';
          _statusController.add(_sessionStatus);
          break;

        case LanMessageType.sessionResumed:
          _sessionStatus = 'active';
          _statusController.add(_sessionStatus);
          break;

        case LanMessageType.sessionSaved:
        case LanMessageType.sessionEnded:
          _sessionStatus = msg.type == LanMessageType.sessionEnded ? 'ended' : 'saved';
          _intentionallyDisconnected = true;
          _reconnectTimer?.cancel();
          _statusController.add(_sessionStatus);
          // The Host closed this live room; retain history, not the old socket.
          disconnect();
          break;

        case LanMessageType.joinAck:
          _hasJoinAck = true;
          break;
        case LanMessageType.pong:
          break;

        default:
          break;
      }
    } catch (_) {
      // Ignore malformed packet lines
    }
  }

  /// Handles unintended socket disconnection and triggers reconnection if enabled.
  void _handleSocketDisconnect([Socket? disconnectedSocket]) {
    if (disconnectedSocket != null && !identical(_socket, disconnectedSocket)) {
      return; // A delayed callback from an older connection must not close a new one.
    }
    _cleanupSocket();
    _hasSnapshot = false;

    if (_state != LanConnectionState.disconnected) {
      _updateState(LanConnectionState.disconnected);
    }

    if (!_intentionallyDisconnected && _autoReconnect && _lastHostAddress != null && _lastPort != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_intentionallyDisconnected && _state == LanConnectionState.disconnected) {
        reconnect();
      }
    });
  }

  /// Attempts to re-establish connection to the Host and requests authoritative state.
  Future<void> reconnect() async {
    if (_disposed || _lastHostAddress == null || _lastPort == null ||
        _sessionStatus == 'ended' || _sessionStatus == 'saved' ||
        _state == LanConnectionState.connected ||
        _state == LanConnectionState.connecting ||
        _state == LanConnectionState.reconnecting) return;
    final generation = ++_connectionGeneration;
    _reconnectTimer?.cancel();
    _intentionallyDisconnected = false;
    _hasSnapshot = false;
    _hasJoinAck = false;

    _updateState(LanConnectionState.reconnecting);

    try {
      final socket = await Socket.connect(
        _lastHostAddress!,
        _lastPort!,
        timeout: const Duration(seconds: 5),
      );
      if (_disposed || generation != _connectionGeneration) {
        socket.destroy();
        return;
      }
      _socket = socket;

      _updateState(LanConnectionState.connected);

      final lineStream = utf8.decoder
          .bind(socket)
          .transform(const LineSplitter());

      _lineSubscription = lineStream.listen(
        _processHostLine,
        onError: (err) => _handleSocketDisconnect(socket),
        onDone: () => _handleSocketDisconnect(socket),
        cancelOnError: true,
      );

      // Re-send join message to trigger stateSnapshot restoration
      send(
        LanMessage.join(
          sessionId: sessionId,
          deviceId: deviceId,
          displayName: displayName,
        ),
      );
    } catch (e) {
      if (!_disposed && generation == _connectionGeneration) {
        _handleSocketDisconnect();
      }
    }
  }

  /// Cleanly disconnects from the Host.
  Future<void> disconnect() async {
    _intentionallyDisconnected = true;
    _connectionGeneration++; // Ignore a Socket.connect that finishes after Leave.
    _hasSnapshot = false;
    _hasJoinAck = false;
    _reconnectTimer?.cancel();

    if (_socket != null && _state == LanConnectionState.connected) {
      try {
        _socket!.write(
          LanMessage.leave(
            sessionId: sessionId,
            deviceId: deviceId,
            displayName: displayName,
          ).serialize(),
        );
      } catch (_) {}
    }

    _cleanupSocket();
    _updateState(LanConnectionState.disconnected);
  }

  void _cleanupSocket() {
    _lineSubscription?.cancel();
    _lineSubscription = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }

  void _updateState(LanConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(_state);
      }
    }
  }

  /// Disposes client streams and timers.
  void dispose() {
    _disposed = true;
    disconnect();
    _stateController.close();
    _messageController.close();
    _pageController.close();
    _statusController.close();
  }
}
