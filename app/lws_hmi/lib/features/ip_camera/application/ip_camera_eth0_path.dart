import 'dart:io';

import 'package:cyber_hal/network.dart';
import 'package:flutter/foundation.dart';

/// Result of one dedicated eth0 camera-segment configure pass.
final class IpCameraEth0ConfigureResult {
  const IpCameraEth0ConfigureResult({
    required this.ok,
    this.tabletIp,
    this.pingOk = false,
    this.detail,
  });

  final bool ok;
  final String? tabletIp;
  final bool pingOk;
  final String? detail;

  static const failed = IpCameraEth0ConfigureResult(ok: false);
}

/// Product topology: bring L3 path to the camera on eth0 (LWS dedicated link).
abstract class IpCameraEth0Path {
  Future<IpCameraEth0ConfigureResult> configure({
    required String cameraIp,
    String? wlanIp,
  });
}

/// Picks tablet eth0 IPv4 on the camera /24 (lws-ui CameraEth0AddressPlanner).
abstract final class IpCameraEth0AddressPlanner {
  static const _candidates = <int>[234, 253, 252, 200, 11];

  static String pickTabletEth0Address(String cameraHost, String? wlanIp) {
    final camera = _parseIpv4(cameraHost);
    if (camera == null) {
      throw ArgumentError.value(
        cameraHost,
        'cameraHost',
        'camera_ip unconfigured or not an IPv4 address',
      );
    }
    final wlan = _parseIpv4(wlanIp);
    final wlanHost =
        wlan != null && _sameSubnet24(camera, wlan) ? wlan.$4 : -1;
    final camHost = camera.$4;

    for (final h in _candidates) {
      if (_usable(h, camHost, wlanHost)) {
        return '${camera.$1}.${camera.$2}.${camera.$3}.$h';
      }
    }
    for (var h = 2; h <= 254; h++) {
      if (_usable(h, camHost, wlanHost)) {
        return '${camera.$1}.${camera.$2}.${camera.$3}.$h';
      }
    }
    return '${camera.$1}.${camera.$2}.${camera.$3}.254';
  }

  static bool _usable(int host, int cameraHost, int wlanHost) {
    if (host <= 0 || host >= 255) {
      return false;
    }
    if (host == cameraHost) {
      return false;
    }
    return host != wlanHost;
  }

  static bool _sameSubnet24(
    (int, int, int, int) a,
    (int, int, int, int) b,
  ) =>
      a.$1 == b.$1 && a.$2 == b.$2 && a.$3 == b.$3;

  static (int, int, int, int)? _parseIpv4(String? raw) {
    if (raw == null) {
      return null;
    }
    final s = raw.trim();
    if (s.isEmpty) {
      return null;
    }
    final parts = s.split('.');
    if (parts.length != 4) {
      return null;
    }
    final octets = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p);
      if (v == null || v < 0 || v > 255) {
        return null;
      }
      octets.add(v);
    }
    return (octets[0], octets[1], octets[2], octets[3]);
  }
}

/// Uses [EthernetController] admin + [setIpv4Config] (networkd via HAL).
final class LinuxIpCameraEth0Path implements IpCameraEth0Path {
  LinuxIpCameraEth0Path({
    required this.ethernet,
    Future<bool> Function(String host)? ping,
  }) : _ping = ping ?? _defaultPing;

  final EthernetController ethernet;
  final Future<bool> Function(String host) _ping;

  @override
  Future<IpCameraEth0ConfigureResult> configure({
    required String cameraIp,
    String? wlanIp,
  }) async {
    final tabletIp =
        IpCameraEth0AddressPlanner.pickTabletEth0Address(cameraIp, wlanIp);
    final desired = EthIpv4Config(
      mode: EthIpv4Mode.staticMode,
      address: tabletIp,
      prefixLength: 24,
      gateway: '',
      dns: '',
    );
    try {
      if (ethernet.currentAdmin != EthAdminState.on) {
        await ethernet.setInterfaceEnabled(true);
      }
      // Avoid networkctl reconfigure (drops RMII carrier) when already applied.
      final current = await ethernet.getIpv4Config();
      final same = current.mode == desired.mode &&
          current.address == desired.address &&
          current.prefixLength == desired.prefixLength &&
          current.gateway == desired.gateway &&
          current.dns == desired.dns;
      if (!same) {
        await ethernet.setIpv4Config(desired);
      }
      await _tuneEth0(ethernet.interfaceName);
      final link = await ethernet.linkDetails();
      final pingOk = await _ping(cameraIp);
      final ok = link.phase != EthLinkPhase.error;
      return IpCameraEth0ConfigureResult(
        ok: ok,
        tabletIp: tabletIp,
        pingOk: pingOk,
        detail: ok ? null : (link.message ?? 'ethernet link error'),
      );
    } catch (e) {
      debugPrint('ip_camera eth0 configure via ethernet HAL failed: $e');
      return IpCameraEth0ConfigureResult(
        ok: false,
        tabletIp: tabletIp,
        detail: '$e',
      );
    }
  }

  static Future<void> _tuneEth0(String iface) async {
    if (!Platform.isLinux) {
      return;
    }
    try {
      await Process.run('/usr/libexec/network/eth0-tune.sh', <String>[iface]);
    } catch (e) {
      debugPrint('ip_camera eth0-tune skipped: $e');
    }
  }

  static Future<bool> _defaultPing(String host) async {
    if (!Platform.isLinux) {
      return false;
    }
    try {
      final result = await Process.run(
        'ping',
        <String>['-c', '1', '-W', '1', host],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

/// No-op path for host/tests.
final class StubIpCameraEth0Path implements IpCameraEth0Path {
  StubIpCameraEth0Path({this.ok = true, this.pingOk = true});

  final bool ok;
  final bool pingOk;

  @override
  Future<IpCameraEth0ConfigureResult> configure({
    required String cameraIp,
    String? wlanIp,
  }) async {
    return IpCameraEth0ConfigureResult(
      ok: ok,
      tabletIp: IpCameraEth0AddressPlanner.pickTabletEth0Address(
        cameraIp,
        wlanIp,
      ),
      pingOk: pingOk,
    );
  }
}
