import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';

/// Orchestrates startup Safety Tips as a first-screen route
/// (lws-ui `SplashActivity` → `SafetyTipsActivity` → `MainActivity`).
abstract final class SafetyTipsCoordinator {
  /// Agree on Safety Tips → replace with Home (lws-ui `toHome`).
  static void goHomeAfterAccept(BuildContext context) {
    SafetyTipsGate.markAccepted();
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  /// Test / hot-restart hook.
  static void resetForTest({bool skipGate = false}) {
    SafetyTipsGate.resetForTest(skip: skipGate);
  }
}
