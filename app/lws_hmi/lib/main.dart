import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';
import 'package:lws_hmi/app/app.dart';
import 'package:lws_hmi/features/home/domain/home_assets.dart';
import 'package:lws_hmi/features/statistics/application/legacy_static_data_migrator.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';
import 'package:lws_hmi/hal/hal_assets.dart';
import 'package:lws_hmi/platform/video_player_elinux/video_player_elinux.dart';

/// Written by oem-compose before HMI starts. No per-board path fallback.
const _kRunBoardProfile = '/run/hmi/board_profile.json';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Warm Home backdrop in parallel with board profile; do not await before
  // runApp (boot KPI — first frame may briefly miss cache, then fill in).
  unawaited(HomeAssets.precacheBackdrop());
  if (Platform.isLinux) {
    // Boot KPI: do not await SQLite / AI before first frame (Plan A C-2).
    unawaited(_migrateLegacyStatistics());
    final isWayland =
        (Platform.environment['WAYLAND_DISPLAY'] ?? '').trim().isNotEmpty;
    if (isWayland) {
      // Weston + flutter-wayland-client links Sony's GStreamer plugin.
      ELinuxVideoPlayer.registerWith();
    } else {
      // eLinux GStreamer texture plugin.
      FlutterpiVideoPlayer.registerWith();
    }
    // AI daemon starts on demand (LiveWeld / AI Vision ensureStarted).
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
  // Host/desktop UI work without an OEM partition (in-code stub, not an asset).
  if (!Platform.isLinux) {
    return HmiHalAssets.hostDevBoardProfile();
  }

  final file = File(_kRunBoardProfile);
  if (!file.existsSync()) {
    throw StateError(
      'Board profile missing: $_kRunBoardProfile. '
      'oem-compose must write it before HMI starts — '
      'no /oem/boards/<id> or App asset fallback on device.',
    );
  }

  final oem = BoardProfile.fromJsonString(file.readAsStringSync());
  return oem.withProductConfigs(
    gpio: HmiHalAssets.gpioForBoard(oem.info.boardId),
    modbus: HmiHalAssets.modbus,
  );
}
