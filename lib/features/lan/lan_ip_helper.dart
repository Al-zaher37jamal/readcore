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
    if (!allowLoopback && (trimmed == '127.0.0.1' || trimmed.startsWith('127.'))) {
      // For production join, we allow loopback only for local tests, but validation warns
      // We'll still consider it valid but caller can decide to show warning
      // For strict validation, we return true but with flag; here we allow but mark
      // Actually for user input we should allow loopback but not recommend
      // So we treat loopback as valid if allowLoopback, otherwise invalid for remote join
      return false;
    }
    final parts = trimmed.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return false;
      if (n < 0 || n > 255) return false;
    }
    return true;
  }

  /// Validates IPv4 for any use (including loopback for tests)
  static bool isValidIPv4Any(String ip) {
    final trimmed = ip.trim();
    if (trimmed.isEmpty) return false;
    final parts = trimmed.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return false;
      if (n < 0 || n > 255) return false;
    }
    return true;
  }

  static bool isLoopback(String ip) {
    return ip.trim() == '127.0.0.1' || ip.trim().startsWith('127.');
  }
}
