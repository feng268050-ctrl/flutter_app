import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';
import 'package:lws_hmi/app/app.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/statistics/application/legacy_static_data_migrator.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';
import 'package:lws_hmi/hal/hal_assets.dart';
import 'package:lws_hmi/platform/video_player_elinux/video_player_elinux.dart';

/// Written by oem-compose before HMI starts. No per-board path fallback.
const _kRunBoardProfile = '/run/hmi/board_profile.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux) {
    await _migrateLegacyStatistics();
  }
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
    // P3.3+: App-owned AI daemon (non-fatal if binary not shipped yet).
    await AiDaemonSupervisor.instance.ensureStarted();
  }
  final profile = await _loadBoardProfile();
  runApp(LwsHmiApp(boardProfile: profile));
}

Future<void> _migrateLegacyStatistics() async {
  final repository = SqliteStatsAggregateRepository();
  try {
    await LegacyStaticDataMigrator(repository: repository).run();
  } finally {
    await repository.close();
  }
}

Future<BoardProfile> _loadBoardProfile() async {
  // Host/desktop UI work without an OEM partition.
  if (!Platform.isLinux) {
    return BoardProfile.loadAsset(HmiHalAssets.boardProfile);
  }

  final file = File(_kRunBoardProfile);
  if (!await file.exists()) {
    throw StateError(
      'Board profile missing: $_kRunBoardProfile. '
      'oem-compose must write it before HMI starts — '
      'no /oem/boards/<id> or App asset fallback on device.',
    );
  }

  final oem = await BoardProfile.loadFile(_kRunBoardProfile);
  return oem.withProductConfigs(
    gpio: HmiHalAssets.gpioForBoard(oem.info.boardId),
    modbus: HmiHalAssets.modbus,
  );
}
