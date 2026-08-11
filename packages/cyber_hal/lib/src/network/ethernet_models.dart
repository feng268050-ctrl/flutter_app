/// Ethernet (eth0 / RJ45) models shared by Demo and later Settings.
enum EthAdminState { off, starting, on, error }

enum EthLinkPhase {
  down,
  noCarrier,
  configuring,
  up,
  error,
}

enum EthIpv4Mode { dhcp, staticMode }

/// Operator DNS preference for eth (independent of [EthIpv4Mode]).
enum EthDnsMode { automatic, manual }

class EthIpv4Config {
  const EthIpv4Config({
    required this.mode,
    this.address = '',
    this.prefixLength = 24,
    this.gateway = '',
    this.dnsMode = EthDnsMode.automatic,
    this.dnsServers = const [],
  });

  /// Legacy single-string DNS — non-empty [dns] means Manual.
  factory EthIpv4Config.withDnsString({
    required EthIpv4Mode mode,
    String address = '',
    int prefixLength = 24,
    String gateway = '',
    String dns = '',
  }) {
    final servers = splitDnsServers(dns);
    return EthIpv4Config(
      mode: mode,
      address: address,
      prefixLength: prefixLength,
      gateway: gateway,
      dnsMode:
          servers.isNotEmpty ? EthDnsMode.manual : EthDnsMode.automatic,
      dnsServers: servers,
    );
  }

  final EthIpv4Mode mode;
  final String address;
  final int prefixLength;
  final String gateway;
  final EthDnsMode dnsMode;
  final List<String> dnsServers;

  /// Space-joined DNS servers (legacy / networkd consumers).
  String get dns => dnsServers.join(' ');

  static const dhcpDefault = EthIpv4Config(mode: EthIpv4Mode.dhcp);

  static List<String> splitDnsServers(String raw) {
    return raw
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  EthIpv4Config copyWith({
    EthIpv4Mode? mode,
    String? address,
    int? prefixLength,
    String? gateway,
    EthDnsMode? dnsMode,
    List<String>? dnsServers,
  }) {
    return EthIpv4Config(
      mode: mode ?? this.mode,
      address: address ?? this.address,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: gateway ?? this.gateway,
      dnsMode: dnsMode ?? this.dnsMode,
      dnsServers: dnsServers ?? this.dnsServers,
    );
  }
}

class EthLinkState {
  const EthLinkState({
    required this.phase,
    this.ipv4,
    this.prefixLength,
    this.gateway,
    this.dns,
    this.mac,
    this.speedMbps,
    this.message,
  });

  final EthLinkPhase phase;
  final String? ipv4;
  final int? prefixLength;
  final String? gateway;
  final String? dns;
  final String? mac;
  final int? speedMbps;
  final String? message;

  bool get hasIpv4 => ipv4 != null && ipv4!.isNotEmpty;

  static const down = EthLinkState(phase: EthLinkPhase.down);

  EthLinkState copyWith({
    EthLinkPhase? phase,
    String? ipv4,
    int? prefixLength,
    String? gateway,
    String? dns,
    String? mac,
    int? speedMbps,
    String? message,
  }) {
    return EthLinkState(
      phase: phase ?? this.phase,
      ipv4: ipv4 ?? this.ipv4,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: gateway ?? this.gateway,
      dns: dns ?? this.dns,
      mac: mac ?? this.mac,
      speedMbps: speedMbps ?? this.speedMbps,
      message: message ?? this.message,
    );
  }
}

/// Persist / parse iface IPv4 prefs under `/var/lib/network/`.
class EthIpv4Store {
  /// Default for `eth0`; prefer `$prefRoot/$iface-ipv4` from the session.
  static const defaultPath = '/var/lib/network/eth0-ipv4';

  static String pathFor(String iface, {String prefRoot = '/var/lib/network'}) =>
      '$prefRoot/$iface-ipv4';

  static String wantedPathFor(String iface, {String prefRoot = '/var/lib/network'}) =>
      '$prefRoot/$iface-wanted';

  static EthIpv4Config parse(String text) {
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
    final mode =
        modeToken == 'static' ? EthIpv4Mode.staticMode : EthIpv4Mode.dhcp;
    final prefix = int.tryParse(map['prefix'] ?? '') ?? 24;
    final servers = EthIpv4Config.splitDnsServers(map['dns'] ?? '');
    final dnsModeToken = (map['dns_mode'] ?? '').toLowerCase();
    final EthDnsMode dnsMode;
    if (dnsModeToken == 'manual') {
      dnsMode = EthDnsMode.manual;
    } else if (dnsModeToken == 'automatic') {
      dnsMode = EthDnsMode.automatic;
    } else {
      dnsMode =
          servers.isNotEmpty ? EthDnsMode.manual : EthDnsMode.automatic;
    }
    return EthIpv4Config(
      mode: mode,
      address: map['address'] ?? '',
      prefixLength: prefix.clamp(0, 32),
      gateway: map['gateway'] ?? '',
      dnsMode: dnsMode,
      dnsServers: servers,
    );
  }

  static String serialize(EthIpv4Config c) {
    final mode = c.mode == EthIpv4Mode.staticMode ? 'static' : 'dhcp';
    final dnsMode =
        c.dnsMode == EthDnsMode.manual ? 'manual' : 'automatic';
    return 'mode=$mode\n'
        'address=${c.address}\n'
        'prefix=${c.prefixLength}\n'
        'gateway=${c.gateway}\n'
        'dns_mode=$dnsMode\n'
        'dns=${c.dns}\n';
  }
}
