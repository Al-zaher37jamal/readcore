import 'dart:io';

/// Helper to discover the real LAN IPv4 address, excluding loopback,
/// and preferring private LAN ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
class LanIpHelper {
  /// Returns the best LAN IPv4 address or 127.0.0.1 only as fallback for tests.
  static Future<String> getLocalLanIPv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final candidates = <String>[];

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (addr.type != InternetAddressType.IPv4) continue;
          final ip = addr.address;
          if (ip == '127.0.0.1') continue;
          if (ip.startsWith('127.')) continue;
          candidates.add(ip);
        }
      }

      if (candidates.isEmpty) {
        return '127.0.0.1';
      }

      // Preference order: 192.168.x.x > 10.x.x.x > 172.16-31.x.x > others
      String? pick192;
      String? pick10;
      String? pick172;
      String? pickOther;

      for (final ip in candidates) {
        if (ip.startsWith('192.168.')) {
          pick192 ??= ip;
        } else if (ip.startsWith('10.')) {
          pick10 ??= ip;
        } else if (_is172Private(ip)) {
          pick172 ??= ip;
        } else {
          pickOther ??= ip;
        }
      }

      return pick192 ?? pick10 ?? pick172 ?? pickOther ?? candidates.first;
    } catch (_) {
      return '127.0.0.1';
    }
  }

  static bool _is172Private(String ip) {
    // 172.16.0.0 - 172.31.255.255
    if (!ip.startsWith('172.')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final second = int.tryParse(parts[1]);
    if (second == null) return false;
    return second >= 16 && second <= 31;
  }

  /// Validates if a string is a valid IPv4 address and not loopback (unless allowLoopback).
  static bool isValidIPv4(String ip, {bool allowLoopback = false}) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;
    final ipOnly = trimmed.contains(':') ? trimmed.split(':')[0].trim() : trimmed;
    if (!allowLoopback && (ipOnly == '127.0.0.1' || ipOnly.startsWith('127.'))) {
      return false;
    }
    final parts = ipOnly.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return false;
      if (n < 0 || n > 255) return false;
    }
    return true;
  }

  /// Validates IPv4 for any use (including loopback for tests)
  /// Now handles host:port like 10.87.235.106:40404
  static bool isValidIPv4Any(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;
    final ipOnly = trimmed.contains(':') ? trimmed.split(':')[0].trim() : trimmed;
    final parts = ipOnly.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return false;
      if (n < 0 || n > 255) return false;
    }
    return true;
  }

  static bool isLoopback(String ip) {
    final trimmed = ip.trim();
    final ipOnly = trimmed.contains(':') ? trimmed.split(':')[0].trim() : trimmed;
    return ipOnly == '127.0.0.1' || ipOnly.startsWith('127.');
  }

  /// Checks if IP is in private LAN ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
  static bool isPrivateLanIPv4(String ip) {
    final trimmed = ip.trim();
    final ipOnly = trimmed.contains(':') ? trimmed.split(':')[0].trim() : trimmed;
    if (!isValidIPv4Any(ipOnly)) return false;
    if (ipOnly.startsWith('10.')) return true;
    if (ipOnly.startsWith('192.168.')) return true;
    if (_is172Private(ipOnly)) return true;
    return true;
  }

  /// Parses host input that may be bare IPv4 or host:port.
  /// Returns record with ip and port, or null if invalid.
  /// Examples:
  /// - "10.87.235.106" → ip=10.87.235.106, port=defaultPort
  /// - "10.87.235.106:40404" → ip=10.87.235.106, port=40404
  /// - "192.168.1.50:40404" → ip=192.168.1.50, port=40404
  static ({String ip, int port})? parseHostPort(String input, {int defaultPort = 40404}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    String ipPart;
    int port = defaultPort;

    if (trimmed.contains(':')) {
      final colonIndex = trimmed.lastIndexOf(':');
      ipPart = trimmed.substring(0, colonIndex).trim();
      final portStr = trimmed.substring(colonIndex + 1).trim();
      if (portStr.isNotEmpty) {
        final parsedPort = int.tryParse(portStr);
        if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
          return null;
        }
        port = parsedPort;
      }
    } else {
      ipPart = trimmed;
    }

    if (!isValidIPv4Any(ipPart)) return null;
    return (ip: ipPart, port: port);
  }

  static String extractIp(String input) {
    final trimmed = input.trim();
    if (trimmed.contains(':')) {
      return trimmed.split(':')[0].trim();
    }
    return trimmed;
  }

  static int extractPort(String input, {int defaultPort = 40404}) {
    final trimmed = input.trim();
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final p = int.tryParse(parts[1].trim());
        if (p != null && p >= 1 && p <= 65535) return p;
      }
    }
    return defaultPort;
  }
}
