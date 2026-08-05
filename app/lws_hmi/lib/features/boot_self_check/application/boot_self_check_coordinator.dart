import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_evaluator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_modbus_snapshot.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_session.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/features/boot_self_check/domain/boot_self_check_item.dart';
import 'package:lws_hmi/features/boot_self_check/presentation/boot_self_check_dialog.dart';

/// Orchestrates once-per-process self-check when Home is entered.
///
/// Each HMI process start shows the dialog again (settings toggle still
/// applies). "Don't show again" only suppresses for the remainder of this
/// process — it no longer writes a permanent preference / boot marker.
abstract final class BootSelfCheckCoordinator {
  /// Visible dwell so each row paints Checking… before the next item.
  static const minStepDuration = Duration(milliseconds: 280);
  static const autoDismissDelay = Duration(seconds: 3);

  static bool _running = false;

  static bool get isRunning => _running;

  /// Starts self-check after Home has painted. Safe to call multiple times.
  static Future<void> startWhenHomeEntered({
    required BuildContext context,
    required AppServices services,
    required BootSelfCheckSettings settings,
    VoidCallback? onComplete,
  }) async {
    if (!context.mounted) {
      onComplete?.call();
      return;
    }
    if (BootSelfCheckGate.shouldSkip) {
      debugPrint('boot-self-check: skip (already completed this process)');
      onComplete?.call();
      return;
    }
    if (!settings.warmRead()) {
      debugPrint('boot-self-check: skip (disabled in settings)');
      BootSelfCheckGate.markCompletedInProcess();
      onComplete?.call();
      return;
    }
    if (_running) {
      debugPrint('boot-self-check: skip (already running)');
      return;
    }
    _running = true;
    BootSelfCheckGate.setActive(true);
    debugPrint('boot-self-check: showing dialog');

    final session = BootSelfCheckSession();
    var userInteracted = false;
    Timer? autoDismissTimer;
    var finished = false;

    Future<void> finish() async {
      if (finished) {
        return;
      }
      finished = true;
      autoDismissTimer?.cancel();
      session.markDismissed();
      // Don't persist "don't show again" — every HMI process start shows again.
      if (context.mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
        }
      }
      BootSelfCheckGate.markCompletedInProcess();
      _running = false;
      debugPrint('boot-self-check: finished');
      onComplete?.call();
    }

    final dialogFuture = showBootSelfCheckDialog(
      context: context,
      session: session,
      onClose: () {
        unawaited(finish());
      },
      onUserInteracted: () {
        userInteracted = true;
        autoDismissTimer?.cancel();
      },
    );

    try {
      // Let the dialog route mount before appending rows.
      await Future<void>.delayed(const Duration(milliseconds: 32));
      debugPrint('boot-self-check: pipeline start');
      await _runPipeline(services: services, session: session);
      debugPrint('boot-self-check: pipeline done rows=${session.rows.length}');
      if (session.dismissed || !context.mounted) {
        await dialogFuture;
        return;
      }
      session.revealFooter();
      autoDismissTimer = Timer(autoDismissDelay, () {
        if (!userInteracted) {
          unawaited(finish());
        }
      });
      await dialogFuture;
      if (!finished) {
        await finish();
      }
    } catch (e, st) {
      debugPrint('boot-self-check: pipeline error: $e\n$st');
      await finish();
    } finally {
      autoDismissTimer?.cancel();
      if (!finished) {
        BootSelfCheckGate.markCompletedInProcess();
        _running = false;
        onComplete?.call();
      }
    }
  }

  /// Yield so [ListenableBuilder] can paint the latest row before the next step.
  static Future<void> _paintFrame() async {
    // Short delay (not endOfFrame): works under widget tests' fake async pumps.
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  static Future<void> _runPipeline({
    required AppServices services,
    required BootSelfCheckSession session,
  }) async {
    // Retry Modbus until the controller is usable (or budget elapses) in
    // parallel with the first Checking… rows. Camera reachability is owned by
    // IpCameraProductSession (status icon).
    final snapshotFuture = BootSelfCheckModbusSnapshotReader.readUntilReady(
      services.modbus,
      shouldCancel: () => session.dismissed,
    );

    BootSelfCheckModbusSnapshot? snapshot;

    for (final item in BootSelfCheckItem.values) {
      if (session.dismissed) {
        return;
      }

      session.appendChecking(item);
      await _paintFrame();

      final sw = Stopwatch()..start();

      snapshot ??= await snapshotFuture;
      if (!snapshot.isUsable) {
        debugPrint(
          'boot-self-check: modbus not ready '
          '(available=${snapshot.modbusAvailable} '
          'controller=${snapshot.controllerReady})',
        );
      }

      final status = BootSelfCheckEvaluator.evaluateItem(
        item: item,
        snapshot: snapshot,
      );

      final remaining = minStepDuration - sw.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (session.dismissed) {
        return;
      }
      session.updateStatus(item, status);
      await _paintFrame();
    }
  }

  /// Test hook.
  ///
  /// [clearBootMarker]: when false, simulates a new HMI process in the same boot.
  static void resetForTest({bool clearBootMarker = true}) {
    _running = false;
    BootSelfCheckGate.resetForTest(clearBootMarker: clearBootMarker);
  }
}
