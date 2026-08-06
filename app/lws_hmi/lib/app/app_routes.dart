import 'package:flutter/material.dart';

/// Named routes for product Home, Settings, Monitor, and hidden Demo.
///
/// Startup: [safetyTips] → (optional [productDisclaimer]) → [home].
/// Boot self-check remains a Home overlay (not a route). Each top-level route
/// calls [scheduleEnsureModbusLive] so live Modbus works even if entry is not
/// Home.
abstract final class AppRoutes {
  static const home = '/';
  /// Startup Safety Tips (lws-ui `SafetyTipsActivity`) — first screen.
  static const safetyTips = '/safety-tips';
  static const settings = '/settings';
  static const monitor = '/monitor';
  static const quickMode = '/process-library/quick';
  static const engineerMode = '/process-library/engineer';
  static const demo = '/demo';
  static const processVideoDetail = '/monitor/process-video';
  static const aiVisionChoose = '/monitor/ai-vision/choose';
  static const systemUpgrade = '/system-upgrade';
  static const controlBoardUpgrade = '/control-board-upgrade';
  /// Product disclaimer (lws-ui `UseSafetyTipsActivity`) — pushed from Safety Tips.
  static const productDisclaimer = '/product-disclaimer';
}

/// Observes top-level route pops so Product Home can re-run home prompts.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
