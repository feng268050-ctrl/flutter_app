import 'package:flutter/material.dart';

/// Named routes for product Home, Settings, Monitor, and hidden Demo.
///
/// Boot self-check is a Home overlay (not a route). Each top-level route calls
/// [scheduleEnsureModbusLive] so live Modbus works even if entry is not Home.
abstract final class AppRoutes {
  static const home = '/';
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
