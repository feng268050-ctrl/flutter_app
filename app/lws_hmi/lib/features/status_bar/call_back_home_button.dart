import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';

export 'package:cyber_ui/cyber_ui.dart'
    show CallBackHomeButton, CyberStatusBarAccent;

extension WorkModeAccentStatusBar on WorkModeAccent {
  CyberStatusBarAccent get statusBarAccent => CyberStatusBarAccent(
        solid: solid,
        // Only weld Back/Home uses the product orange press peak. Cleaning
        // and cutting deliberately keep their existing green / blue peaks.
        pressCenter: family == WorkModeAccentFamily.weld &&
                solid == const Color(0xFFF46E01)
            ? const Color(0xFFF46E01)
            : pressCenter,
      );
}
