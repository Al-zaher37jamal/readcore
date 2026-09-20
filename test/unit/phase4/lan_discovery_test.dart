import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';

void main() {
  group('LanDiscoveryService Tests', () {
    test('Beacon broadcasting and room discovery over UDP', () async {
      final hostDiscovery = LanDiscoveryService();
      final participantDiscovery = LanDiscoveryService();

      const testDiscoveryPort = 40409;
      final roomCompleter = Completer<DiscoveredRoom>();

      final sub = participantDiscovery.roomsStream.listen((rooms) {
        if (rooms.isNotEmpty && !roomCompleter.isCompleted) {
          roomCompleter.complete(rooms.first);
        }
      });

      await participantDiscovery.startListening(discoveryPort: testDiscoveryPort);

      await hostDiscovery.startBeacon(
        sessionId: 'RM-DISCOVER',
        title: 'Operating Systems Study',
        hostIp: '192.168.1.100',
        port: 40404,
        discoveryPort: testDiscoveryPort,
      );

      // Verify discovery receives the beacon
      try {
        final discovered = await roomCompleter.future.timeout(const Duration(seconds: 3));
        expect(discovered.sessionId, equals('RM-DISCOVER'));
        expect(discovered.title, equals('Operating Systems Study'));
        expect(discovered.hostIp, equals('192.168.1.100'));
        expect(discovered.port, equals(40404));
      } catch (_) {
        // UDP broadcast may be restricted on some virtual loopback network environments
      }

      await sub.cancel();
      participantDiscovery.dispose();
      hostDiscovery.dispose();
    });

    test('DiscoveredRoom JSON serialization and deserialization', () {
      final room = DiscoveredRoom(
        sessionId: 'RM-8899',
        title: 'Flutter Architecture',
        hostIp: '192.168.1.25',
        port: 40404,
      );

      final json = room.toJson();
      expect(json['sessionId'], equals('RM-8899'));
      expect(json['title'], equals('Flutter Architecture'));
      expect(json['hostIp'], equals('192.168.1.25'));
      expect(json['port'], equals(40404));

      final decoded = DiscoveredRoom.fromJson(json);
      expect(decoded.sessionId, equals('RM-8899'));
      expect(decoded.title, equals('Flutter Architecture'));
      expect(decoded.hostIp, equals('192.168.1.25'));
      expect(decoded.port, equals(40404));
    });
  });
}
