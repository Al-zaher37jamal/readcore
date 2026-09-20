import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Information about a discovered Host room on the local network.
class DiscoveredRoom {
  final String sessionId;
  final String title;
  final String hostIp;
  final int port;
  final DateTime lastSeen;

  DiscoveredRoom({
    required this.sessionId,
    required this.title,
    required this.hostIp,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'title': title,
        'hostIp': hostIp,
        'port': port,
      };

  factory DiscoveredRoom.fromJson(Map<String, dynamic> json) {
    return DiscoveredRoom(
      sessionId: json['sessionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      hostIp: json['hostIp'] as String? ?? '127.0.0.1',
      port: json['port'] as int? ?? 40404,
    );
  }
}

/// Simple LAN UDP beacon and discovery service for local Wi-Fi / Hotspot rooms.
class LanDiscoveryService {
  static const int defaultDiscoveryPort = 40405;

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _beaconTimer;

  final Map<String, DiscoveredRoom> _discoveredRooms = {};
  final StreamController<List<DiscoveredRoom>> _roomsController =
      StreamController<List<DiscoveredRoom>>.broadcast();

  Stream<List<DiscoveredRoom>> get roomsStream => _roomsController.stream;
  List<DiscoveredRoom> get discoveredRooms => _discoveredRooms.values.toList();

  /// Starts periodic UDP broadcasting for a Host room.
  Future<void> startBeacon({
    required String sessionId,
    required String title,
    required String hostIp,
    required int port,
    int discoveryPort = defaultDiscoveryPort,
  }) async {
    stopBeacon();

    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _broadcastSocket?.broadcastEnabled = true;

      final beaconData = utf8.encode(
        jsonEncode({
          'type': 'readmesh_beacon',
          'sessionId': sessionId,
          'title': title,
          'hostIp': hostIp,
          'port': port,
        }),
      );

      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        try {
          _broadcastSocket?.send(
            beaconData,
            InternetAddress('255.255.255.255'),
            discoveryPort,
          );
        } catch (_) {}
      });
    } catch (_) {
      // Graceful fallback if UDP broadcast is restricted
    }
  }

  /// Stops the Host beacon.
  void stopBeacon() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  /// Starts listening for Host beacons on the local network.
  Future<void> startListening({int discoveryPort = defaultDiscoveryPort}) async {
    stopListening();

    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );

      _listenSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });
    } catch (_) {
      // Graceful fallback
    }
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (json['type'] == 'readmesh_beacon') {
        final room = DiscoveredRoom.fromJson(json);
        if (room.sessionId.isNotEmpty) {
          _discoveredRooms[room.sessionId] = room;
          if (!_roomsController.isClosed) {
            _roomsController.add(_discoveredRooms.values.toList());
          }
        }
      }
    } catch (_) {}
  }

  /// Stops listening for beacons.
  void stopListening() {
    _listenSocket?.close();
    _listenSocket = null;
    _discoveredRooms.clear();
  }

  /// Disposes discovery service.
  void dispose() {
    stopBeacon();
    stopListening();
    _roomsController.close();
  }
}
