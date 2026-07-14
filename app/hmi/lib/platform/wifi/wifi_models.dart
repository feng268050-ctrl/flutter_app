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

class WifiAccessPoint {
  const WifiAccessPoint({
    required this.ssid,
    this.signalDbm,
    this.flags = '',
  });

  final String ssid;
  final int? signalDbm;
  final String flags;

  bool get isOpen =>
      !flags.contains('WPA') && !flags.contains('WEP') && !flags.contains('RSN');
}

class WifiSavedNetwork {
  const WifiSavedNetwork({required this.networkId, required this.ssid});

  final int networkId;
  final String ssid;
}

class WlanIpv4Config {
  const WlanIpv4Config({
    required this.mode,
    this.address = '',
    this.prefixLength = 24,
    this.gateway = '',
    this.dns = '',
  });

  final WlanIpv4Mode mode;
  final String address;
  final int prefixLength;
  final String gateway;
  final String dns;

  static const dhcpDefault = WlanIpv4Config(mode: WlanIpv4Mode.dhcp);

  WlanIpv4Config copyWith({
    WlanIpv4Mode? mode,
    String? address,
    int? prefixLength,
    String? gateway,
    String? dns,
  }) {
    return WlanIpv4Config(
      mode: mode ?? this.mode,
      address: address ?? this.address,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: gateway ?? this.gateway,
      dns: dns ?? this.dns,
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
      message: message ?? this.message,
    );
  }
}

/// Persist / parse `/var/lib/lws-hmi/wlan0-ipv4`.
class WlanIpv4Store {
  static const defaultPath = '/var/lib/lws-hmi/wlan0-ipv4';

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
    return WlanIpv4Config(
      mode: mode,
      address: map['address'] ?? '',
      prefixLength: prefix.clamp(0, 32),
      gateway: map['gateway'] ?? '',
      dns: map['dns'] ?? '',
    );
  }

  static String serialize(WlanIpv4Config c) {
    final mode = c.mode == WlanIpv4Mode.staticMode ? 'static' : 'dhcp';
    return 'mode=$mode\n'
        'address=${c.address}\n'
        'prefix=${c.prefixLength}\n'
        'gateway=${c.gateway}\n'
        'dns=${c.dns}\n';
  }
}
