import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/material.dart';
import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';
import 'package:lws_hmi/app/app.dart';
import 'package:lws_hmi/hal/hal_assets.dart';
import 'package:lws_hmi/platform/video_player_elinux/video_player_elinux.dart';

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
  final profile = await BoardProfile.loadAsset(HmiHalAssets.boardProfile);
  runApp(LwsHmiApp(boardProfile: profile));
}
