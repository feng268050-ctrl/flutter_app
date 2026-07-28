import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart';
import 'package:dbus/dbus.dart';

/// True when [iface] is a real IEEE 802.11 netdev (`wireless` / `phy80211`).
///
/// P3.2 QEMU renames a virtio-net NIC to `wlan0` as a **role stand-in** — that
/// path is Ethernet L3 only and must not start `wpa_supplicant`.
Future<bool> wifiIfaceIsIeee80211(String iface) async {
  if (iface.isEmpty || iface == 'lo') {
    return false;
  }
  final base = '/sys/class/net/$iface';
  if (!await Directory(base).exists()) {
    return false;
  }
  return await Directory('$base/wireless').exists() ||
      await Directory('$base/phy80211').exists();
}

/// Board-specific Wi‑Fi PHY / radio bring-up (D11b).
///
/// Portable HAL calls this port. Default is [SystemdWifiRadio] (no board
/// scripts). Optional [WifiModemPort] covers combo-module firmware only.
abstract class WifiRadio {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

/// Optional modem / SDIO / UART firmware bring-up before netdev exists.
///
/// Default [NoopWifiModemPort] assumes the wireless iface is already present.
/// Boards whose Wi‑Fi module needs firmware/`insmod`/vendor init **must** inject
/// a [WifiModemPort] (profile `helpers.wifi_modem`). Case study: ynh960
/// `wifibt-bringup.sh` — see `docs/network-stack.md` § Modem bring-up.
/// Prefer netdev name **`wlan0`** (ethernet **`eth0`**); see
/// `docs/hal-portability.md`.
abstract class WifiModemPort {
  Future<void> ensureRadioHardware();
}

/// No-op modem port — netdev already present.
final class NoopWifiModemPort implements WifiModemPort {
  const NoopWifiModemPort();

  @override
  Future<void> ensureRadioHardware() async {}
}

/// Runs an optional board bring-up command (e.g. wifibt-bringup.sh).
final class ProcessWifiModemPort implements WifiModemPort {
  ProcessWifiModemPort({
    this.command = const <String>[],
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) : _run = run ?? ((exe, args) => Process.run(exe, args));

  final List<String> command;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  @override
  Future<void> ensureRadioHardware() async {
    if (command.isEmpty) {
      return;
    }
    lwsTrace('wifi-modem: ${command.join(' ')}');
    final r = await _run(command.first, command.sublist(1));
    if (r.exitCode != 0) {
      throw StateError(
        'WifiModemPort failed (${command.first}): ${r.stderr}',
      );
    }
  }
}

/// Portable Wi‑Fi radio: conf + `ip link` + systemd unit + wpa D-Bus ready.
///
/// Does **not** call board stack scripts. Modem firmware is optional via
/// [modem].
final class SystemdWifiRadio implements WifiRadio {
  SystemdWifiRadio({
    this.iface,
    this.wpaConfPath = '/var/lib/wpa_supplicant/wpa_supplicant.conf',
    this.wifiWantedPath = '/var/lib/wpa_supplicant/wifi-wanted',
    this.ifaceFilePath = '/run/wpa-wlan.iface',
    this.wlanUnit = 'wlan-wpa.service',
    this.stockWpaUnit = 'wpa_supplicant.service',
    this.country = 'CN',
    WifiModemPort? modem,
    Future<ProcessResult> Function(String exe, List<String> args)? run,
    DBusClient Function()? busFactory,
  })  : modem = modem ?? const NoopWifiModemPort(),
        _run = run ?? ((exe, args) => Process.run(exe, args)),
        _busFactory = busFactory;

  /// Preferred wireless iface; null → discover `*/wireless` or `wlan0`.
  final String? iface;
  final String wpaConfPath;
  final String wifiWantedPath;
  final String ifaceFilePath;
  final String wlanUnit;
  final String stockWpaUnit;
  final String country;
  final WifiModemPort modem;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;
  final DBusClient Function()? _busFactory;

  @override
  Future<bool> isEnabled() async {
    try {
      final ifc = await _resolveIface(fallbackOnly: true);
      if (!await wifiIfaceIsIeee80211(ifc)) {
        final wanted = await File(wifiWantedPath).exists();
        if (!wanted) {
          return false;
        }
        final r = await _run('ip', <String>['-o', 'link', 'show', 'dev', ifc]);
        return r.exitCode == 0 && '${r.stdout}'.contains('UP');
      }
      final r = await _run('systemctl', <String>['is-active', wlanUnit]);
      return '${r.stdout}'.trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _bringUp();
    } else {
      await _tearDown();
    }
  }

  Future<void> _bringUp() async {
    await modem.ensureRadioHardware();
    final ifc = await _resolveIface();
    await _writeIfaceFile(ifc);
    await _run('ip', <String>['link', 'set', ifc, 'up']);
    if (!await wifiIfaceIsIeee80211(ifc)) {
      // Virtio / renamed Ethernet stand-in for wifi.station — L3 only.
      await _writeWanted(true);
      lwsTrace('wifi-radio: stand-in L3-only $ifc (no IEEE 802.11 / skip wpa)');
      return;
    }
    await _ensureWpaConf();
    // Empty D-Bus-activated stock daemon owns fi.w1.wpa_supplicant1.
    await _run('systemctl', <String>['stop', stockWpaUnit]);
    await _run('systemctl', <String>['reset-failed', wlanUnit]);
    final start = await _run('systemctl', <String>['start', wlanUnit]);
    if (start.exitCode != 0) {
      throw StateError('$wlanUnit failed to start: ${start.stderr}');
    }
    await _waitWpaIface(ifc);
    await _writeWanted(true);
    lwsTrace('wifi-radio: up $ifc via $wlanUnit');
  }

  Future<void> _tearDown() async {
    final ifc = await _resolveIface(fallbackOnly: true);
    final ieee = await wifiIfaceIsIeee80211(ifc);
    if (ieee) {
      await _run('systemctl', <String>['stop', wlanUnit]);
      await _run('systemctl', <String>['reset-failed', wlanUnit]);
    }
    if (await Directory('/sys/class/net/$ifc').exists()) {
      await _run('ip', <String>['link', 'set', ifc, 'down']);
    }
    await _writeWanted(false);
    lwsTrace('wifi-radio: down $ifc');
  }

  Future<void> _ensureWpaConf() async {
    final f = File(wpaConfPath);
    if (await f.exists()) {
      return;
    }
    await f.parent.create(recursive: true);
    await f.writeAsString(
      'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root\n'
      'update_config=1\n'
      'country=$country\n',
      flush: true,
    );
    try {
      await Process.run('chmod', ['600', wpaConfPath]);
    } catch (_) {}
  }

  Future<String> _resolveIface({bool fallbackOnly = false}) async {
    if (iface != null && iface!.isNotEmpty) {
      if (fallbackOnly || await Directory('/sys/class/net/$iface').exists()) {
        return iface!;
      }
    }
    try {
      final runFile = File(ifaceFilePath);
      if (await runFile.exists()) {
        final name = (await runFile.readAsString()).trim();
        if (name.isNotEmpty) {
          return name;
        }
      }
    } catch (_) {}
    final discovered = await _detectWireless();
    if (discovered != null) {
      return discovered;
    }
    if (fallbackOnly) {
      return iface ?? 'wlan0';
    }
    throw StateError(
      'SystemdWifiRadio: no wireless netdev '
      '(profile iface=${iface ?? 'null'}; inject WifiModemPort if needed)',
    );
  }

  Future<String?> _detectWireless() async {
    final root = Directory('/sys/class/net');
    if (!await root.exists()) {
      return null;
    }
    await for (final entity in root.list()) {
      if (entity is! Directory) {
        continue;
      }
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name == 'lo' ||
          name.startsWith('eth') ||
          name.startsWith('end') ||
          name.startsWith('sit') ||
          name.startsWith('tun') ||
          name.startsWith('tap') ||
          name.startsWith('dummy') ||
          name.startsWith('usb')) {
        continue;
      }
      if (await Directory('${entity.path}/wireless').exists() ||
          await Directory('${entity.path}/phy80211').exists()) {
        return name;
      }
    }
    return null;
  }

  Future<void> _writeIfaceFile(String ifc) async {
    final f = File(ifaceFilePath);
    await f.parent.create(recursive: true);
    await f.writeAsString('$ifc\n', flush: true);
  }

  Future<void> _writeWanted(bool wanted) async {
    final f = File(wifiWantedPath);
    try {
      if (wanted) {
        await f.parent.create(recursive: true);
        await f.writeAsString('', flush: true);
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  Future<void> _waitWpaIface(String ifc) async {
    DBusClient? bus;
    try {
      bus = _busFactory?.call() ?? DBusClient.system();
      final wpa = WpaSupplicantDbus(client: bus);
      for (var i = 0; i < 40; i++) {
        try {
          final snap = await wpa.readIface(ifc);
          if (snap.wpaStateToken.isNotEmpty &&
              snap.wpaStateToken != 'INTERFACE_DISABLED') {
            return;
          }
        } catch (_) {}
        final failed = await _run(
          'systemctl',
          <String>['is-failed', wlanUnit],
        );
        if ('${failed.stdout}'.trim() == 'failed') {
          throw StateError('$wlanUnit failed while waiting for $ifc');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw StateError('wpa D-Bus Interface not ready on $ifc');
    } finally {
      if (_busFactory == null) {
        await bus?.close();
      }
    }
  }
}

/// Legacy adapter: systemd unit check + board stack scripts.
///
/// Retained for transition; **not** the HAL default ([SystemdWifiRadio] is).
final class ScriptWifiRadio implements WifiRadio {
  ScriptWifiRadio({
    this.stackUp = const <String>[],
    this.stackDown = const <String>[],
    this.activeUnit = 'wlan-wpa.service',
    Future<ProcessResult> Function(String exe, List<String> args)? run,
  }) : _run = run ?? ((exe, args) => Process.run(exe, args));

  final List<String> stackUp;
  final List<String> stackDown;
  final String activeUnit;
  final Future<ProcessResult> Function(String exe, List<String> args) _run;

  @override
  Future<bool> isEnabled() async {
    try {
      final r = await _run('systemctl', <String>['is-active', activeUnit]);
      return '${r.stdout}'.trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final cmd = enabled ? stackUp : stackDown;
    if (cmd.isEmpty) {
      throw StateError('WifiRadio: empty ${enabled ? 'stackUp' : 'stackDown'}');
    }
    final r = await _run(cmd.first, cmd.sublist(1));
    if (r.exitCode != 0) {
      throw StateError('${cmd.first} failed: ${r.stderr}');
    }
  }
}
