/// Wi-Fi models shared by Demo and later P5.2 Settings.
enum WifiRadioState { off, starting, on, error }

enum WifiConnectionPhase {
  disconnected,
  associating,
  obtainingIp,
  connected,
  failed,
}

enum WlanIpv4Mode { dhcp, staticMode }

/// Operator DNS preference for wlan0 (independent of [WlanIpv4Mode]).
enum WlanDnsMode { automatic, manual }

class WifiAccessPoint {
  const WifiAccessPoint({
    required this.ssid,
    this.signalDbm,
    this.flags = '',
    this.bssid,
  });

  final String ssid;
  final int? signalDbm;
  final String flags;
  final String? bssid;

  /// Open / OWE / no PSK — do not prompt for a password.
  ///
  /// Uses PSK/SAE/WEP tokens, not a bare `WPA` substring (RSN shells used to
  /// be mapped to `[WPA2-PSK-…]` incorrectly).
  bool get isOpen {
    final f = flags.toUpperCase();
    if (f.contains('WEP')) {
      return false;
    }
    if (f.contains('PSK') || f.contains('SAE')) {
      return false;
    }
    return true;
  }

  /// Alias for HAL scaffold callers (!isOpen).
  bool get secured => !isOpen;
}

class WifiSavedNetwork {
  const WifiSavedNetwork({
    required this.networkId,
    required this.ssid,
    this.autoJoin = true,
  });

  final int networkId;
  final String ssid;

  /// When false, wpa will not auto-select this network (`disabled` / Enabled=false).
  final bool autoJoin;
}

class WlanIpv4Config {
  const WlanIpv4Config({
    required this.mode,
    this.address = '',
    this.prefixLength = 24,
    this.gateway = '',
    this.dnsMode = WlanDnsMode.automatic,
    this.dnsServers = const [],
  });

  /// Legacy single-string DNS ctor — treats non-empty [dns] as Manual.
  factory WlanIpv4Config.withDnsString({
    required WlanIpv4Mode mode,
    String address = '',
    int prefixLength = 24,
    String gateway = '',
    String dns = '',
  }) {
    final servers = splitDnsServers(dns);
    return WlanIpv4Config(
      mode: mode,
      address: address,
      prefixLength: prefixLength,
      gateway: gateway,
      dnsMode:
          servers.isNotEmpty ? WlanDnsMode.manual : WlanDnsMode.automatic,
      dnsServers: servers,
    );
  }

  final WlanIpv4Mode mode;
  final String address;
  final int prefixLength;
  final String gateway;
  final WlanDnsMode dnsMode;
  final List<String> dnsServers;

  /// Space-joined DNS servers (legacy single-string consumers).
  String get dns => dnsServers.join(' ');

  static const dhcpDefault = WlanIpv4Config(mode: WlanIpv4Mode.dhcp);

  static List<String> splitDnsServers(String raw) {
    return raw
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  WlanIpv4Config copyWith({
    WlanIpv4Mode? mode,
    String? address,
    int? prefixLength,
    String? gateway,
    WlanDnsMode? dnsMode,
    List<String>? dnsServers,
  }) {
    return WlanIpv4Config(
      mode: mode ?? this.mode,
      address: address ?? this.address,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: gateway ?? this.gateway,
      dnsMode: dnsMode ?? this.dnsMode,
      dnsServers: dnsServers ?? this.dnsServers,
    );
  }
}

class WifiConnectionState {
  const WifiConnectionState({
    required this.phase,
    this.ssid,
    this.bssid,
    this.ipv4,
    this.prefixLength,
    this.gateway,
    this.dns,
    this.frequencyMhz,
    this.signalDbm,
    this.macAddress,
    this.linkSpeedMbps,
    this.security,
    this.message,
  });

  final WifiConnectionPhase phase;
  final String? ssid;
  final String? bssid;
  final String? ipv4;
  final int? prefixLength;
  final String? gateway;
  final String? dns;
  final int? frequencyMhz;
  final int? signalDbm;

  /// Station interface MAC (e.g. wlan0), when known.
  final String? macAddress;

  /// Negotiated link rate in Mbps, when reported by the driver / `iw`.
  final int? linkSpeedMbps;

  /// User-facing security label (Open / WPA2 / WPA3 / …) for the current BSS.
  final String? security;
  final String? message;

  bool get isAssociated =>
      phase == WifiConnectionPhase.connected ||
      phase == WifiConnectionPhase.obtainingIp;

  static const disconnected = WifiConnectionState(
    phase: WifiConnectionPhase.disconnected,
  );

  WifiConnectionState copyWith({
    WifiConnectionPhase? phase,
    String? ssid,
    String? bssid,
    String? ipv4,
    int? prefixLength,
    String? gateway,
    String? dns,
    int? frequencyMhz,
    int? signalDbm,
    String? macAddress,
    int? linkSpeedMbps,
    String? security,
    String? message,
  }) {
    return WifiConnectionState(
      phase: phase ?? this.phase,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      ipv4: ipv4 ?? this.ipv4,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: gateway ?? this.gateway,
      dns: dns ?? this.dns,
      frequencyMhz: frequencyMhz ?? this.frequencyMhz,
      signalDbm: signalDbm ?? this.signalDbm,
      macAddress: macAddress ?? this.macAddress,
      linkSpeedMbps: linkSpeedMbps ?? this.linkSpeedMbps,
      security: security ?? this.security,
      message: message ?? this.message,
    );
  }
}

/// Persist / parse iface IPv4 prefs under `/var/lib/wpa_supplicant/`.
class WlanIpv4Store {
  /// Default for `wlan0`; prefer `$prefRoot/$iface-ipv4` from the session.
  static const defaultPath = '/var/lib/wpa_supplicant/wlan0-ipv4';

  static String pathFor(String iface, {String prefRoot = '/var/lib/wpa_supplicant'}) =>
      '$prefRoot/$iface-ipv4';

  static WlanIpv4Config parse(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) {
        continue;
      }
      final i = t.indexOf('=');
      if (i <= 0) {
        continue;
      }
      map[t.substring(0, i).trim()] = t.substring(i + 1).trim();
    }
    final modeToken = (map['mode'] ?? 'dhcp').toLowerCase();
    final mode = modeToken == 'static'
        ? WlanIpv4Mode.staticMode
        : WlanIpv4Mode.dhcp;
    final prefix = int.tryParse(map['prefix'] ?? '') ?? 24;
    final servers = WlanIpv4Config.splitDnsServers(map['dns'] ?? '');
    final dnsModeToken = (map['dns_mode'] ?? '').toLowerCase();
    final WlanDnsMode dnsMode;
    if (dnsModeToken == 'manual') {
      dnsMode = WlanDnsMode.manual;
    } else if (dnsModeToken == 'automatic' || dnsModeToken == 'auto') {
      dnsMode = WlanDnsMode.automatic;
    } else if (servers.isNotEmpty && mode == WlanIpv4Mode.staticMode) {
      // Legacy prefs: non-empty dns under static ⇒ Manual.
      dnsMode = WlanDnsMode.manual;
    } else {
      dnsMode = WlanDnsMode.automatic;
    }
    return WlanIpv4Config(
      mode: mode,
      address: map['address'] ?? '',
      prefixLength: prefix.clamp(0, 32),
      gateway: map['gateway'] ?? '',
      dnsMode: dnsMode,
      dnsServers: servers,
    );
  }

  static String serialize(WlanIpv4Config c) {
    final mode = c.mode == WlanIpv4Mode.staticMode ? 'static' : 'dhcp';
    final dnsMode =
        c.dnsMode == WlanDnsMode.manual ? 'manual' : 'automatic';
    return 'mode=$mode\n'
        'address=${c.address}\n'
        'prefix=${c.prefixLength}\n'
        'gateway=${c.gateway}\n'
        'dns_mode=$dnsMode\n'
        'dns=${c.dns}\n';
  }
}
