import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/ethernet/ethernet_controller.dart';
import 'package:lws_hmi/platform/ethernet/ethernet_models.dart';
import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/wifi/wifi_link_parse.dart';

/// Linux wired Ethernet via on-demand helpers + `ip` / sysfs.
/// Product image pins GMAC to `eth0` (`10-lws-hmi-gmac.link`).
class LinuxEthernetController implements EthernetController {
  LinuxEthernetController({
    this.iface = 'eth0',
    this.linkHelper = const ['/usr/lib/lws-hmi/eth0-link.sh'],
    this.dhcpHelper = const ['/usr/lib/lws-hmi/eth0-dhcp.sh'],
    this.staticHelper = const ['/usr/lib/lws-hmi/eth0-static.sh'],
    this.ipv4Path = EthIpv4Store.defaultPath,
    this.ethWantedPath = '/var/lib/lws-hmi/eth0-wanted',
  });

  final String iface;
  final List<String> linkHelper;
  final List<String> dhcpHelper;
  final List<String> staticHelper;
  final String ipv4Path;
  final String ethWantedPath;

  @override
  String get interfaceName => iface;

  final _adminCtrl = StreamController<EthAdminState>.broadcast();
  final _linkCtrl = StreamController<EthLinkState>.broadcast();

  EthAdminState _admin = EthAdminState.off;
  EthLinkState _link = EthLinkState.down;
  Timer? _poll;
  Timer? _wantedWatch;
  int _wantedTicks = 0;

  static const _wantedWatchMaxTicks = 120;

  @override
  EthAdminState get currentAdmin => _admin;

  @override
  EthLinkState get currentLink => _link;

  @override
  Stream<EthAdminState> get admin => _adminCtrl.stream;

  @override
  Stream<EthLinkState> get link => _linkCtrl.stream;

  Map<String, String> get _env => {
        ...Platform.environment,
        'LWS_ETH_IFACE': iface,
      };

  void _emitAdmin(EthAdminState s) {
    _admin = s;
    if (!_adminCtrl.isClosed) {
      _adminCtrl.add(s);
    }
  }

  void _emitLink(EthLinkState s) {
    _link = s;
    if (!_linkCtrl.isClosed) {
      _linkCtrl.add(s);
    }
  }

  Future<ProcessResult> _run(List<String> cmd, {bool log = true}) async {
    if (cmd.isEmpty) {
      return ProcessResult(0, 1, '', 'empty command');
    }
    if (log) {
      lwsTrace('ethernet[$iface]: ${cmd.join(' ')}');
    }
    return Process.run(cmd.first, cmd.sublist(1), environment: _env);
  }

  String _processFailMessage(ProcessResult r, String fallback) {
    final err = (r.stderr as String? ?? '').trim();
    final out = (r.stdout as String? ?? '').trim();
    if (err.isNotEmpty) {
      return err;
    }
    if (out.isNotEmpty) {
      return out;
    }
    return '$fallback (exit ${r.exitCode})';
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshStatus());
    });
  }

  void _stopWantedWatch() {
    _wantedWatch?.cancel();
    _wantedWatch = null;
    _wantedTicks = 0;
  }

  void _startWantedWatch() {
    _stopWantedWatch();
    _wantedWatch = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickWantedWatch());
    });
  }

  Future<void> _tickWantedWatch() async {
    _wantedTicks++;
    try {
      if (await _isAdminUp()) {
        _stopWantedWatch();
        _emitAdmin(EthAdminState.on);
        _startPoll();
        await _refreshStatus();
        return;
      }
      if (_admin == EthAdminState.starting) {
        _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
      }
      if (_wantedTicks >= _wantedWatchMaxTicks) {
        _stopWantedWatch();
        await setInterfaceEnabled(true);
      }
    } catch (e) {
      debugPrint('ethernet: wanted watch: $e');
    }
  }

  Future<void> _refreshStatus() async {
    final details = await linkDetails();
    _emitLink(details);
  }

  @override
  Future<void> setInterfaceEnabled(bool enabled) async {
    _stopWantedWatch();
    if (enabled) {
      _emitAdmin(EthAdminState.starting);
      _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
      if (!Directory('/sys/class/net/$iface').existsSync()) {
        final msg =
            '$iface missing (expected RJ45 netdev; PHY/gmac may not have probed)';
        debugPrint('ethernet: $msg');
        _emitAdmin(EthAdminState.error);
        _emitLink(EthLinkState(phase: EthLinkPhase.error, message: msg));
        return;
      }
      final r = await _run([...linkHelper, 'up']);
      if (r.exitCode != 0) {
        final msg = _processFailMessage(r, 'eth0-link up failed');
        debugPrint('ethernet: $msg');
        _emitAdmin(EthAdminState.error);
        _emitLink(EthLinkState(phase: EthLinkPhase.error, message: msg));
        return;
      }
      _emitAdmin(EthAdminState.on);
      _startPoll();
      final cfg = await getIpv4Config();
      final apply = await _applyIpv4(cfg);
      if (!apply.ok) {
        debugPrint('ethernet: ${apply.message}');
        _emitLink(
          EthLinkState(
            phase: EthLinkPhase.error,
            message: apply.message,
          ),
        );
      } else {
        await _writeWanted(true);
      }
      await _refreshStatus();
    } else {
      _poll?.cancel();
      _poll = null;
      await _run([...linkHelper, 'down']);
      await _writeWanted(false);
      _emitAdmin(EthAdminState.off);
      _emitLink(EthLinkState.down);
    }
  }

  Future<void> _writeWanted(bool wanted) async {
    try {
      final f = File(ethWantedPath);
      if (wanted) {
        await f.parent.create(recursive: true);
        await f.writeAsString('', flush: true);
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('ethernet: wanted marker failed: $e');
    }
  }

  Future<({bool ok, String? message})> _applyIpv4(EthIpv4Config cfg) async {
    if (cfg.mode == EthIpv4Mode.dhcp) {
      final r = await _run([...dhcpHelper, 'start']);
      if (r.exitCode != 0) {
        return (
          ok: false,
          message: _processFailMessage(r, 'eth0-dhcp failed'),
        );
      }
      return (ok: true, message: null);
    }
    final r = await _run([
      ...staticHelper,
      cfg.address,
      '${cfg.prefixLength}',
      if (cfg.gateway.isNotEmpty) cfg.gateway else '',
      if (cfg.dns.isNotEmpty) cfg.dns else '',
    ]);
    if (r.exitCode != 0) {
      return (
        ok: false,
        message: _processFailMessage(r, 'eth0-static failed'),
      );
    }
    return (ok: true, message: null);
  }

  Future<bool> _isAdminUp() async {
    try {
      final flags = await File('/sys/class/net/$iface/flags').readAsString();
      final v = int.tryParse(flags.trim()) ?? 0;
      return (v & 0x1) != 0;
    } catch (_) {
      final r = await _run(['ip', '-br', 'link', 'show', iface], log: false);
      final out = (r.stdout as String? ?? '').toUpperCase();
      return out.contains('UP');
    }
  }

  Future<bool> _hasCarrier() async {
    try {
      final c = await File('/sys/class/net/$iface/carrier').readAsString();
      return c.trim() == '1';
    } catch (_) {
      try {
        final op =
            await File('/sys/class/net/$iface/operstate').readAsString();
        return op.trim() == 'up';
      } catch (_) {
        return false;
      }
    }
  }

  Future<String?> _readMac() async {
    try {
      return (await File('/sys/class/net/$iface/address').readAsString())
          .trim();
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readSpeedMbps() async {
    try {
      final s = await File('/sys/class/net/$iface/speed').readAsString();
      return int.tryParse(s.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<EthLinkState> linkDetails() async {
    if (!Directory('/sys/class/net/$iface').existsSync()) {
      return EthLinkState(
        phase: EthLinkPhase.error,
        message: '$iface missing',
      );
    }
    final adminUp = await _isAdminUp();
    if (!adminUp) {
      return EthLinkState.down;
    }
    final carrier = await _hasCarrier();
    if (!carrier) {
      return EthLinkState(
        phase: EthLinkPhase.noCarrier,
        mac: await _readMac(),
      );
    }

    final addrR = await _run(
      ['ip', '-4', '-o', 'addr', 'show', 'dev', iface],
      log: false,
    );
    final inet = WifiLinkParse.inet4(addrR.stdout as String? ?? '');
    final gwR = await _run(['ip', '-4', 'route', 'show', 'default'], log: false);
    final gw = WifiLinkParse.defaultGateway(gwR.stdout as String? ?? '');
    String? dns;
    try {
      final resolv = await File('/etc/resolv.conf').readAsString();
      dns = WifiLinkParse.primaryDns(resolv);
    } catch (_) {}

    final hasIp = inet.address != null && inet.address!.isNotEmpty;
    return EthLinkState(
      phase: hasIp ? EthLinkPhase.up : EthLinkPhase.configuring,
      ipv4: inet.address,
      prefixLength: inet.prefix,
      gateway: gw,
      dns: dns,
      mac: await _readMac(),
      speedMbps: await _readSpeedMbps(),
    );
  }

  @override
  Future<EthIpv4Config> getIpv4Config() async {
    try {
      final f = File(ipv4Path);
      if (!await f.exists()) {
        return EthIpv4Config.dhcpDefault;
      }
      return EthIpv4Store.parse(await f.readAsString());
    } catch (_) {
      return EthIpv4Config.dhcpDefault;
    }
  }

  @override
  Future<void> setIpv4Config(EthIpv4Config config) async {
    final f = File(ipv4Path);
    await f.parent.create(recursive: true);
    await f.writeAsString(EthIpv4Store.serialize(config), flush: true);
    if (_admin == EthAdminState.on) {
      _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
      final apply = await _applyIpv4(config);
      if (!apply.ok) {
        debugPrint('ethernet: ${apply.message}');
        _emitLink(
          EthLinkState(
            phase: EthLinkPhase.error,
            message: apply.message,
          ),
        );
      } else {
        await _writeWanted(true);
      }
      await _refreshStatus();
    }
  }

  @override
  Future<void> syncFromSystem() async {
    try {
      final wanted = await File(ethWantedPath).exists();
      final adminUp = await _isAdminUp();
      if (adminUp) {
        _stopWantedWatch();
        _emitAdmin(EthAdminState.on);
        _startPoll();
        await _refreshStatus();
        return;
      }
      if (wanted) {
        _emitAdmin(EthAdminState.starting);
        _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
        _startWantedWatch();
      }
    } catch (e) {
      debugPrint('ethernet: syncFromSystem failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _stopWantedWatch();
    _poll?.cancel();
    await _adminCtrl.close();
    await _linkCtrl.close();
  }
}
