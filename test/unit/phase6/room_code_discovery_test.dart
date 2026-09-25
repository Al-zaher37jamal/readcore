import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';
import 'package:readmesh/features/lan/lan_ip_helper.dart';

void main() {
  test('UDP beacon resolves a room code without any manually entered Host IP',
      () async {
    final service = LanDiscoveryService();
    final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      await service.startListening(discoveryPort: 0);
      expect(service.isListening, isTrue);
      final found = service.roomsStream.firstWhere((rooms) =>
          rooms.any((r) => r.sessionId == 'RM-3721'))
          .timeout(const Duration(seconds: 3));
      sender.send(utf8.encode(jsonEncode({
        'type': 'readmesh_beacon', 'sessionId': 'RM-3721',
        'title': 'Offline book', 'hostIp': '10.87.235.106', 'port': 40404,
      })), InternetAddress.loopbackIPv4, service.listeningPort!);
      expect((await found).single.title, 'Offline book');
      final match = service.roomForCode(' rm-3721 ');
      expect(match?.hostIp, '10.87.235.106');
      expect(match?.port, 40404);
      expect(LanIpHelper.parseHostPort('${match!.hostIp}:${match.port}')?.port,
          40404);
      expect(service.roomForCode('RM-OTHER'), isNull);
      service.stopListening();
      expect(service.roomForCode('RM-3721'), isNull);
    } finally {
      sender.close();
      service.dispose();
    }
  });

  test('IP:port validation remains an explicit fallback if discovery fails', () {
    expect(LanIpHelper.parseHostPort('10.87.235.106')?.port, 40404);
    expect(LanIpHelper.parseHostPort('10.87.235.106:40404')?.ip,
        '10.87.235.106');
    expect(LanIpHelper.parseHostPort('not-an-ip'), isNull);
    expect(LanIpHelper.isLoopback('127.0.0.1'), isTrue);
  });
}
