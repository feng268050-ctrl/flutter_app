import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/src/core/board_info.dart';
import 'package:cyber_hal/src/core/capabilities.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/sys_info/storage_part_labels.dart';
import 'package:flutter/services.dart';

export 'package:cyber_hal/src/sys_info/storage_part_labels.dart'
    show kDefaultSystemStoragePartLabels;

/// Well-known keys under [BoardProfile.helpers] (D22 live wiring).
abstract final class BoardHelperKeys {
  static const syncTime = 'sync_time';
  static const usbOtgMode = 'usb_otg_mode';
  static const otgModeSysfs = 'otg_mode_sysfs';
  static const sshDebug = 'ssh_debug';
  static const btA2dpVolume = 'bt_a2dp_volume';
  static const btStackUp = 'bt_stack_up';
  static const btStackDown = 'bt_stack_down';
  static const btA2dpUp = 'bt_a2dp_up';
  static const btA2dpDown = 'bt_a2dp_down';
  static const btEnsureAgent = 'bt_ensure_agent';
  static const btStopAgent = 'bt_stop_agent';
  static const btSetAlias = 'bt_set_alias';
  static const wifiStackUp = 'wifi_stack_up';
  static const wifiStackDown = 'wifi_stack_down';
  static const wifiModem = 'wifi_modem';
  static const wifiWlanUnit = 'wifi_wlan_unit';
  static const btModem = 'bt_modem';
  static const btBluetoothUnit = 'bt_bluetooth_unit';
  static const applyProxy = 'apply_proxy';
  static const changeBacklight = 'change_backlight';
  static const changeVolume = 'change_volume';
  static const applyMouseSettings = 'apply_mouse_settings';
  /// Comma-separated preferred `/sys/class/backlight` basenames.
  static const backlightPreferredNames = 'backlight_preferred_names';
  /// Comma-separated preferred ALSA simple mixer volume controls.
  static const alsaVolumeControls = 'alsa_volume_controls';
  /// Optional ALSA enum control name for speaker route (e.g. `Playback Path`).
  static const alsaPlaybackPathControl = 'alsa_playback_path_control';
  /// Value for [alsaPlaybackPathControl] (e.g. Rockchip `RING_SPK_HP`).
  static const alsaPlaybackPathValue = 'alsa_playback_path_value';
  /// Explicit mpg123 ALSA PCM (`-a`), e.g. plughw:0,0.
  static const alsaOutputDevice = 'alsa_output_device';
  /// Optional IPC / camera host for boot self-check ICMP (e.g. `192.168.1.100`).
  static const cameraIp = 'camera_ip';
  /// Override [ModbusTransport.device] from product `modbus.json` (e.g. sim
  /// USB-RS485 → `/dev/ttyUSB0` while ynh960 keeps `/dev/ttyS5`).
  static const modbusRtuDevice = 'modbus_rtu_device';
}

/// Board profile: capabilities, net role→iface, pointers to gpio/modbus configs.
final class BoardProfile {
  const BoardProfile({
    required this.info,
    required this.capabilities,
    required this.netRoles,
    this.gpioConfigAsset,
    this.modbusConfigAsset,
    this.storageMounts = const ['/', '/userdata'],
    this.systemStoragePartLabels = kDefaultSystemStoragePartLabels,
    this.routeMetrics = const {},
    this.helpers = const {},
    this.secretsBackend,
  });

  final BoardInfo info;
  final Capabilities capabilities;
  final Map<NetRole, String> netRoles;
  final String? gpioConfigAsset;
  final String? modbusConfigAsset;
  final List<String> storageMounts;

  /// GPT part labels whose full size rolls into System (excludes userdata).
  final List<String> systemStoragePartLabels;

  /// Iface → systemd-networkd RouteMetric (lower preferred). Empty → HAL defaults.
  final Map<String, int> routeMetrics;

  /// Board Process / sysfs paths keyed by [BoardHelperKeys] (D22).
  final Map<String, String> helpers;

  /// Preferred Secrets backend: `software` or `optee` (see package secrets).
  ///
  /// JSON key `secrets_backend`. When null, [BoardBindings] uses board-id
  /// heuristics (sim/emu → software; else → optee).
  final String? secretsBackend;

  String? ifaceFor(NetRole role) => netRoles[role];

  int? routeMetricFor(String iface) => routeMetrics[iface];

  String? helper(String key) {
    final v = helpers[key];
    if (v == null || v.isEmpty) {
      return null;
    }
    return v;
  }

  /// Single-argv helper command from [helpers], or null if unset.
  List<String>? helperArgv(String key) {
    final path = helper(key);
    if (path == null) {
      return null;
    }
    return <String>[path];
  }

  /// Comma-separated list helper (e.g. backlight names / ALSA controls).
  List<String>? helperList(String key) {
    final raw = helper(key);
    if (raw == null) {
      return null;
    }
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  /// Flutter asset URI for [gpioConfigAsset].
  ///
  /// Absolute app/package paths (`assets/…`, `packages/…`) are kept as-is.
  /// Relative paths resolve under `packages/cyber_hal/` (example profiles only).
  String? get resolvedGpioAsset => _resolveConfigAsset(gpioConfigAsset);

  /// Flutter asset URI for [modbusConfigAsset].
  String? get resolvedModbusAsset => _resolveConfigAsset(modbusConfigAsset);

  static String? _resolveConfigAsset(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('packages/') || path.startsWith('assets/')) {
      return path;
    }
    return 'packages/cyber_hal/$path';
  }

  /// Load a profile JSON asset (e.g. app `assets/hal/board_profile.json` or
  /// package `packages/cyber_hal/boards/sim.json`).
  static Future<BoardProfile> loadAsset(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    return BoardProfile.fromJsonString(source);
  }

  /// Load a board profile from an absolute filesystem path (OEM / compose).
  static Future<BoardProfile> loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw HalIoException('board profile missing: $path');
    }
    try {
      return BoardProfile.fromJsonString(await file.readAsString());
    } on HalIoException {
      rethrow;
    } catch (e) {
      throw HalIoException('board profile read failed ($path): $e');
    }
  }

  /// Copy with App-owned gpio/modbus Flutter asset paths merged in.
  BoardProfile withProductConfigs({
    String? gpio,
    String? modbus,
  }) {
    return BoardProfile(
      info: info,
      capabilities: capabilities,
      netRoles: netRoles,
      gpioConfigAsset: gpio ?? gpioConfigAsset,
      modbusConfigAsset: modbus ?? modbusConfigAsset,
      storageMounts: storageMounts,
      systemStoragePartLabels: systemStoragePartLabels,
      routeMetrics: routeMetrics,
      helpers: helpers,
      secretsBackend: secretsBackend,
    );
  }

  factory BoardProfile.fromJson(Map<String, dynamic> json) {
    final boardId = json['board_id'] as String?;
    if (boardId == null || boardId.isEmpty) {
      throw const HalIoException('board profile missing board_id');
    }

    final capsRaw = json['capabilities'];
    final caps = capsRaw is List
        ? Capabilities.fromIds(capsRaw.map((e) => '$e'))
        : const Capabilities({});

    final roles = <NetRole, String>{};
    final net = json['net_roles'];
    if (net is Map) {
      net.forEach((key, value) {
        final role = NetRole.tryParse('$key');
        if (role != null && value is String) {
          roles[role] = value;
        }
      });
    }

    final configs = json['configs'];
    String? gpioAsset;
    String? modbusAsset;
    if (configs is Map) {
      gpioAsset = configs['gpio'] as String?;
      modbusAsset = configs['modbus'] as String?;
    }

    final mounts = <String>[];
    final storage = json['storage_mounts'];
    if (storage is List) {
      mounts.addAll(storage.map((e) => '$e'));
    }

    final systemParts = <String>[];
    final systemLabels = json['system_storage_part_labels'];
    if (systemLabels is List) {
      systemParts.addAll(
        systemLabels.map((e) => '$e'.trim()).where((e) => e.isNotEmpty),
      );
    }

    final metrics = <String, int>{};
    final rm = json['route_metrics'];
    if (rm is Map) {
      rm.forEach((key, value) {
        final n = value is int ? value : int.tryParse('$value');
        if (n != null) {
          metrics['$key'] = n;
        }
      });
    }

    final helpers = <String, String>{};
    final rawHelpers = json['helpers'];
    if (rawHelpers is Map) {
      rawHelpers.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          helpers['$key'] = value;
        }
      });
    }

    String? secretsBackend;
    final secretsRaw = json['secrets_backend'];
    if (secretsRaw is String && secretsRaw.trim().isNotEmpty) {
      secretsBackend = secretsRaw.trim();
    }

    return BoardProfile(
      info: BoardInfo(
        boardId: boardId,
        displayName: json['display_name'] as String?,
        modelHint: json['model_hint'] as String?,
      ),
      capabilities: caps,
      netRoles: roles,
      gpioConfigAsset: gpioAsset,
      modbusConfigAsset: modbusAsset,
      storageMounts: mounts.isEmpty ? const ['/', '/userdata'] : mounts,
      systemStoragePartLabels: systemParts.isEmpty
          ? kDefaultSystemStoragePartLabels
          : List<String>.unmodifiable(systemParts),
      routeMetrics: metrics,
      helpers: helpers,
      secretsBackend: secretsBackend,
    );
  }

  factory BoardProfile.fromJsonString(String source) =>
      BoardProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
