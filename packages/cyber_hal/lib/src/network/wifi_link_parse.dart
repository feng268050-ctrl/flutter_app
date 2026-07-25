/// Pure parsers for `ip` / resolv text used to build [WifiLinkDetails].
class WifiLinkParse {
  /// `ip -4 -o addr show dev wlan0` → (address, prefix).
  static ({String? address, int? prefix}) inet4(String text) {
    final m = RegExp(
      r'inet\s+(\d+\.\d+\.\d+\.\d+)(?:/(\d+))?',
    ).firstMatch(text);
    if (m == null) {
      return (address: null, prefix: null);
    }
    return (
      address: m.group(1),
      prefix: int.tryParse(m.group(2) ?? ''),
    );
  }

  /// `ip -4 route show default` → first via gateway.
  static String? defaultGateway(String text) {
    for (final line in text.split('\n')) {
      final m = RegExp(r'default\s+via\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(line);
      if (m != null) {
        return m.group(1);
      }
    }
    return null;
  }

  /// IPv4 prefix length → dotted subnet mask (e.g. 24 → 255.255.255.0).
  static String? ipv4PrefixToSubnetMask(int? prefixLength) {
    if (prefixLength == null || prefixLength < 0 || prefixLength > 32) {
      return null;
    }
    if (prefixLength == 0) {
      return '0.0.0.0';
    }
    final mask = prefixLength == 32
        ? 0xFFFFFFFF
        : (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
    return [
      (mask >> 24) & 0xFF,
      (mask >> 16) & 0xFF,
      (mask >> 8) & 0xFF,
      mask & 0xFF,
    ].join('.');
  }

  /// `iw dev wlan0 link` → negotiated tx bitrate in Mbps (best-effort).
  static int? linkSpeedMbpsFromIw(String text) {
    final m = RegExp(
      r'tx bitrate:\s*([\d.]+)\s*([MG])Bit/s',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) {
      return null;
    }
    final rate = double.tryParse(m.group(1)!);
    if (rate == null) {
      return null;
    }
    final unit = m.group(2)!.toUpperCase();
    final mbps = unit == 'G' ? rate * 1000 : rate;
    return mbps.round();
  }

  /// `/etc/resolv.conf` style → first nameserver.
  static String? primaryDns(String text) {
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.startsWith('nameserver ')) {
        final parts = t.split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[1].isNotEmpty) {
          return parts[1];
        }
      }
    }
    return null;
  }
}
