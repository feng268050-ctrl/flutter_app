import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';
import 'package:lws_hmi/app/app.dart';
import 'package:lws_hmi/hal/hal_assets.dart';
import 'package:lws_hmi/platform/video_player_elinux/video_player_elinux.dart';

/// Compose export (preferred) then on-device OEM board pack.
const _kRunBoardProfile = '/run/hmi/board_profile.json';
const _kOemBoardProfile = '/oem/boards/ynh960/board_profile.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    final isWayland =
        (Platform.environment['WAYLAND_DISPLAY'] ?? '').trim().isNotEmpty;
    if (isWayland) {
      // Weston + flutter-wayland-client links Sony's GStreamer plugin.
      ELinuxVideoPlayer.registerWith();
    } else {
      // eLinux GStreamer texture plugin.
      FlutterpiVideoPlayer.registerWith();
    }
  }
  final profile = await _loadBoardProfile();
  runApp(LwsHmiApp(boardProfile: profile));
}

Future<BoardProfile> _loadBoardProfile() async {
  for (final path in <String>[_kRunBoardProfile, _kOemBoardProfile]) {
    final file = File(path);
    if (!await file.exists()) {
      continue;
    }
    try {
      final oem = await BoardProfile.loadFile(path);
      return oem.withProductConfigs(
        gpio: HmiHalAssets.gpio,
        modbus: HmiHalAssets.modbus,
      );
    } catch (e, st) {
      debugPrint('board profile load failed ($path): $e\n$st');
    }
  }

  // Host/desktop: App asset is OK for UI work without an OEM partition.
  // On-device Linux: refuse App asset fallback — fix oem-compose /oem.
  if (!Platform.isLinux) {
    return BoardProfile.loadAsset(HmiHalAssets.boardProfile);
  }
  throw StateError(
    'OEM/compose board profile missing '
    '(tried $_kRunBoardProfile, $_kOemBoardProfile). '
    'Check oem-compose.service and oem.img — no App asset fallback on device.',
  );
}
