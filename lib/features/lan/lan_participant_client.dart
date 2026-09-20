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

  // Last connection parameters for reconnecting
  String? _lastHostAddress;
  int? _lastPort;

  Timer? _reconnectTimer;
  final bool _autoReconnect;
  bool _intentionallyDisconnected = false;

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
    _lastHostAddress = hostAddress;
    _lastPort = port;
    _intentionallyDisconnected = false;

    _updateState(LanConnectionState.connecting);

    try {
      _socket = await Socket.connect(hostAddress, port, timeout: timeout);

      _updateState(LanConnectionState.connected);

      // Listen to line-delimited JSON stream
      final lineStream = utf8.decoder
          .bind(_socket!)
          .transform(const LineSplitter());

      _lineSubscription = lineStream.listen(
        _processHostLine,
        onError: (err) => _handleSocketDisconnect(),
        onDone: () => _handleSocketDisconnect(),
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
      _handleSocketDisconnect();
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

  /// Processes a single line received from the Host.
  void _processHostLine(String line) {
    try {
      final msg = LanMessage.deserialize(line);
      _messageController.add(msg);

      switch (msg.type) {
        case LanMessageType.stateSnapshot:
          if (msg.currentPage != null) {
            _currentPage = msg.currentPage!;
            _pageController.add(_currentPage);
          }
          if (msg.totalPages != null) {
            _totalPages = msg.totalPages!;
          }
          if (msg.sessionStatus != null) {
            _sessionStatus = msg.sessionStatus!;
            _statusController.add(_sessionStatus);
          }
          break;

        case LanMessageType.pageChanged:
          if (msg.currentPage != null) {
            _currentPage = msg.currentPage!;
            _pageController.add(_currentPage);
          }
          if (msg.totalPages != null) {
            _totalPages = msg.totalPages!;
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

        case LanMessageType.sessionEnded:
          _sessionStatus = 'ended';
          _statusController.add(_sessionStatus);
          break;

        case LanMessageType.joinAck:
        case LanMessageType.pong:
          // Informational acknowledgments
          break;

        default:
          break;
      }
    } catch (_) {
      // Ignore malformed packet lines
    }
  }

  /// Handles unintended socket disconnection and triggers reconnection if enabled.
  void _handleSocketDisconnect() {
    _cleanupSocket();

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
    if (_lastHostAddress == null || _lastPort == null) return;
    _reconnectTimer?.cancel();

    _updateState(LanConnectionState.reconnecting);

    try {
      _socket = await Socket.connect(
        _lastHostAddress!,
        _lastPort!,
        timeout: const Duration(seconds: 5),
      );

      _updateState(LanConnectionState.connected);

      final lineStream = utf8.decoder
          .bind(_socket!)
          .transform(const LineSplitter());

      _lineSubscription = lineStream.listen(
        _processHostLine,
        onError: (err) => _handleSocketDisconnect(),
        onDone: () => _handleSocketDisconnect(),
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
      _handleSocketDisconnect();
    }
  }

  /// Cleanly disconnects from the Host.
  Future<void> disconnect() async {
    _intentionallyDisconnected = true;
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
    disconnect();
    _stateController.close();
    _messageController.close();
    _pageController.close();
    _statusController.close();
  }
}
