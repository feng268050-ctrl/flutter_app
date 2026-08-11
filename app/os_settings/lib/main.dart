import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/app/services.dart';

/// Written by oem-compose before HMI / OS Settings starts.
const _kRunBoardProfile = '/run/hmi/board_profile.json';

/// Host / desktop UI without an OEM partition.
const _kHostBoardProfileAsset = 'assets/board_profile.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profile = await _loadBoardProfile();
  final services = OsSettingsServices(boardProfile: profile);
  await services.wallpaper().warmRead();
  // Reflect live Wi‑Fi / Ethernet / BT — never disable on seat switch.
  unawaited(services.observePlatformStacks());
  runApp(OsSettingsApp(services: services));
}

/// Loads OEM [BoardProfile] only — never merges product gpio/modbus.
Future<BoardProfile> _loadBoardProfile() async {
  if (Platform.isLinux) {
    final file = File(_kRunBoardProfile);
    if (await file.exists()) {
      return BoardProfile.loadFile(_kRunBoardProfile);
    }
  }
  // Host/desktop (or Linux without oem-compose): stub asset, no product configs.
  return BoardProfile.loadAsset(_kHostBoardProfileAsset);
}
