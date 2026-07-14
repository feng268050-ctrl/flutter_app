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
