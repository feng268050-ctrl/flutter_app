import 'package:flutter/material.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';
import 'package:lws_hmi/features/safety_tips/presentation/safety_tips_dialog.dart';

/// Orchestrates the startup Safety Tips gate before Home continues
/// (lws-ui `SplashActivity` → `SafetyTipsActivity`).
abstract final class SafetyTipsCoordinator {
  static bool _running = false;

  static bool get isRunning => _running;

  /// Shows Safety Tips after Home has painted. Safe to call multiple times.
  ///
  /// Raises [SafetyTipsGate.isActive] for the duration so [GlobalPromptQueue]
  /// cannot present register/bind/Wi‑Fi tips over the disclaimer.
  static Future<void> showWhenHomeEntered({
    required BuildContext context,
    VoidCallback? onComplete,
  }) async {
    if (!context.mounted) {
      onComplete?.call();
      return;
    }
    if (SafetyTipsGate.shouldSkip) {
      onComplete?.call();
      return;
    }
    if (_running) {
      return;
    }
    _running = true;
    SafetyTipsGate.setActive(true);
    try {
      await showSafetyTipsDialog(context: context);
      SafetyTipsGate.markAccepted();
    } finally {
      SafetyTipsGate.setActive(false);
      _running = false;
      onComplete?.call();
    }
  }

  /// Test / hot-restart hook.
  static void resetForTest({bool skipGate = false}) {
    _running = false;
    SafetyTipsGate.resetForTest(skip: skipGate);
  }
}
