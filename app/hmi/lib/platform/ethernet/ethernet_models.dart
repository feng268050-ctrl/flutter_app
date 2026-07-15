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

class EthIpv4Config {
  const EthIpv4Config({
    required this.mode,
    this.address = '',
    this.prefixLength = 24,
    this.gateway = '',
    this.dns = '',
  });

  final EthIpv4Mode mode;
  final String address;
  final int prefixLength;
  final String gateway;
  final String dns;

  static const dhcpDefault = EthIpv4Config(mode: EthIpv4Mode.dhcp);

  EthIpv4Config copyWith({
    EthIpv4Mode? mode,
    String? address,
    int? prefixLength,
    String? gateway,
    String? dns,
  }) {
    return EthIpv4Config(
      mode: mode ?? this.mode,
      address: address ?? this.address,
      prefixLength: prefixLength ?? this.prefixLength,
      gateway: gateway ?? this.gateway,
      dns: dns ?? this.dns,
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

/// Persist / parse `/var/lib/lws-hmi/eth0-ipv4`.
class EthIpv4Store {
  static const defaultPath = '/var/lib/lws-hmi/eth0-ipv4';

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
    return EthIpv4Config(
      mode: mode,
      address: map['address'] ?? '',
      prefixLength: prefix.clamp(0, 32),
      gateway: map['gateway'] ?? '',
      dns: map['dns'] ?? '',
    );
  }

  static String serialize(EthIpv4Config c) {
    final mode = c.mode == EthIpv4Mode.staticMode ? 'static' : 'dhcp';
    return 'mode=$mode\n'
        'address=${c.address}\n'
        'prefix=${c.prefixLength}\n'
        'gateway=${c.gateway}\n'
        'dns=${c.dns}\n';
  }
}
