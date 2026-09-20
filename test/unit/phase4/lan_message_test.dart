import 'package:flutter_test/flutter_test.dart';
import 'package:readmesh/features/lan/lan_message.dart';

void main() {
  group('LanMessage Protocol Serialization & Deserialization Tests', () {
    test('Serializes and deserializes JOIN message', () {
      final msg = LanMessage.join(
        sessionId: 'RM-1234',
        deviceId: 'dev_part_1',
        displayName: 'Alice',
      );

      final line = msg.serialize();
      expect(line.endsWith('\n'), isTrue);

      final decoded = LanMessage.deserialize(line);
      expect(decoded.type, equals(LanMessageType.join));
      expect(decoded.sessionId, equals('RM-1234'));
      expect(decoded.senderDeviceId, equals('dev_part_1'));
      expect(decoded.senderName, equals('Alice'));
    });

    test('Serializes and deserializes STATE_SNAPSHOT message', () {
      final msg = LanMessage.stateSnapshot(
        sessionId: 'RM-5678',
        hostDeviceId: 'dev_host_1',
        currentPage: 15,
        totalPages: 50,
        sessionStatus: 'active',
        participants: [
          {'deviceId': 'dev_part_1', 'displayName': 'Bob', 'role': 'participant'},
        ],
      );

      final line = msg.serialize();
      final decoded = LanMessage.deserialize(line);

      expect(decoded.type, equals(LanMessageType.stateSnapshot));
      expect(decoded.sessionId, equals('RM-5678'));
      expect(decoded.senderDeviceId, equals('dev_host_1'));
      expect(decoded.currentPage, equals(15));
      expect(decoded.totalPages, equals(50));
      expect(decoded.sessionStatus, equals('active'));
      expect(decoded.payload?['participants'], isNotEmpty);
    });

    test('Serializes and deserializes PAGE_CHANGED message', () {
      final msg = LanMessage.pageChanged(
        sessionId: 'RM-9999',
        hostDeviceId: 'dev_host_1',
        currentPage: 42,
        totalPages: 100,
      );

      final line = msg.serialize();
      final decoded = LanMessage.deserialize(line);

      expect(decoded.type, equals(LanMessageType.pageChanged));
      expect(decoded.currentPage, equals(42));
      expect(decoded.totalPages, equals(100));
    });

    test('Serializes and deserializes session lifecycle messages (start, pause, resume, end)', () {
      final start = LanMessage.sessionStarted(sessionId: 'RM-1', hostDeviceId: 'dev_h', currentPage: 1);
      final pause = LanMessage.sessionPaused(sessionId: 'RM-1', hostDeviceId: 'dev_h', currentPage: 5);
      final resume = LanMessage.sessionResumed(sessionId: 'RM-1', hostDeviceId: 'dev_h', currentPage: 5);
      final end = LanMessage.sessionEnded(sessionId: 'RM-1', hostDeviceId: 'dev_h', currentPage: 10);

      expect(LanMessage.deserialize(start.serialize()).type, equals(LanMessageType.sessionStarted));
      expect(LanMessage.deserialize(start.serialize()).sessionStatus, equals('active'));

      expect(LanMessage.deserialize(pause.serialize()).type, equals(LanMessageType.sessionPaused));
      expect(LanMessage.deserialize(pause.serialize()).sessionStatus, equals('paused'));

      expect(LanMessage.deserialize(resume.serialize()).type, equals(LanMessageType.sessionResumed));
      expect(LanMessage.deserialize(resume.serialize()).sessionStatus, equals('active'));

      expect(LanMessage.deserialize(end.serialize()).type, equals(LanMessageType.sessionEnded));
      expect(LanMessage.deserialize(end.serialize()).sessionStatus, equals('ended'));
    });

    test('Throws FormatException on empty or whitespace deserialize input', () {
      expect(() => LanMessage.deserialize('   '), throwsA(isA<FormatException>()));
    });
  });
}
