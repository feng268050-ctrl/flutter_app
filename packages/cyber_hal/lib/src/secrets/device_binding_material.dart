import 'dart:io';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/sys_info/sys_info.dart';

/// Stable hardware factors used to derive the software KEK (never persisted).
final class DeviceBindingMaterial {
  const DeviceBindingMaterial({
    required this.chipId,
    this.dtSerial = '',
    this.ethMac = '',
    this.wlanMac = '',
    this.mmcCid = '',
  });

  /// SoC / chip serial (`read-serial --chip-id`). Required.
  final String chipId;

  /// Device-tree `serial-number` when present and distinct from [chipId].
  final String dtSerial;

  /// Primary ethernet MAC (`/sys/class/net/eth0/address`).
  final String ethMac;

  /// Station Wi‑Fi MAC (`/sys/class/net/wlan0/address`).
  final String wlanMac;

  /// eMMC/SD CID (`/sys/block/mmcblk*/device/cid`) when present.
  final String mmcCid;

  /// Canonical IKM string for HKDF (ordered, labeled, deterministic).
  String get canonicalIkm {
    final lines = <String>['v3', 'chip=${chipId.trim().toLowerCase()}'];
    void add(String key, String value) {
      final v = value.trim().toLowerCase();
      if (v.isEmpty) {
        return;
      }
      lines.add('$key=$v');
    }

    add('dt', dtSerial);
    add('eth', ethMac);
    add('wlan', wlanMac);
    add('mmc', mmcCid);
    return '${lines.join('\n')}\n';
  }

  /// Non-empty factors excluding duplicates of chip id.
  int get distinctFactorCount {
    final chip = chipId.trim().toLowerCase();
    var n = chip.isEmpty ? 0 : 1;
    for (final v in <String>[dtSerial, ethMac, wlanMac, mmcCid]) {
      final t = v.trim().toLowerCase();
      if (t.isEmpty || t == chip) {
        continue;
      }
      n++;
    }
    return n;
  }
}

/// Loads [DeviceBindingMaterial] (injectable in tests).
typedef DeviceBindingMaterialReader = Future<DeviceBindingMaterial> Function();

/// Legacy alias — chip-only inject; prefer [DeviceBindingMaterialReader].
typedef ChipIdReader = Future<String> Function();

/// Reads sysfs / DT / `read-serial` factors for software KEK binding.
final class DeviceBindingMaterialCollector {
  const DeviceBindingMaterialCollector({
    this.deviceSnReader = const DeviceSnReader(),
    this.ethIface = 'eth0',
    this.wlanIface = 'wlan0',
  });

  final DeviceSnReader deviceSnReader;
  final String ethIface;
  final String wlanIface;

  /// Ensures chip id plus at least one other distinct factor.
  static void validate(DeviceBindingMaterial m) {
    if (m.chipId.trim().isEmpty) {
      throw const HalIoException(
        'software KEK: chip id unavailable (cannot bind to device)',
      );
    }
    if (m.distinctFactorCount < 2) {
      throw HalIoException(
        'software KEK: need chip id plus at least one other factor '
        '(eth MAC / wlan MAC / eMMC CID / distinct DT serial); '
        'got only chip=${m.chipId}',
      );
    }
  }

  Future<DeviceBindingMaterial> collect() async {
    final chipRaw = (await deviceSnReader.readChipId()).trim();
    final chipId = (chipRaw.isEmpty || chipRaw == '-') ? '' : chipRaw;

    final dt = await _readDtSerial();
    final eth = await _readMac(ethIface);
    final wlan = await _readMac(wlanIface);
    final mmc = await _readMmcCid();

    final material = DeviceBindingMaterial(
      chipId: chipId,
      dtSerial: (dt.isNotEmpty && dt.toLowerCase() != chipId.toLowerCase())
          ? dt
          : '',
      ethMac: eth,
      wlanMac: wlan,
      mmcCid: mmc,
    );
    validate(material);
    return material;
  }

  static Future<String> _readDtSerial() async {
    for (final path in const <String>[
      '/proc/device-tree/serial-number',
      '/sys/firmware/devicetree/base/serial-number',
    ]) {
      final v = await _readTrimNull(path);
      if (v.isNotEmpty) {
        return v;
      }
    }
    return '';
  }

  static Future<String> _readMac(String iface) async {
    return _readTrimNull('/sys/class/net/$iface/address');
  }

  static Future<String> _readMmcCid() async {
    for (final path in const <String>[
      '/sys/block/mmcblk0/device/cid',
      '/sys/block/mmcblk1/device/cid',
      '/sys/block/mmcblk2/device/cid',
    ]) {
      final v = await _readTrimNull(path);
      if (v.isNotEmpty) {
        return v;
      }
    }
    return '';
  }

  static Future<String> _readTrimNull(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return '';
      }
      var s = await file.readAsString();
      s = s.replaceAll('\x00', '').trim();
      return s;
    } catch (_) {
      return '';
    }
  }
}
