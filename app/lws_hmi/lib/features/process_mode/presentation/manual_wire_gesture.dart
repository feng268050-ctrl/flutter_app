import 'dart:async';

import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';

/// Shared Feed/Retract pointer protocol for Quick and Engineer panels.
///
/// Short press → 500ms pulse. Hold ≥500ms starts continuous motion; Feed
/// latches after 3s total and stops on the next tap; Retract runs only while
/// pressed.
///
/// Toast copy mirrors lws-ui `GeneralOperationsFragment` wire host callbacks.
final class ManualWireGesture {
  ManualWireGesture({
    required this.controller,
    required this.retract,
    required this.isEnabled,
    required this.isActive,
    required this.onMessage,
    required this.onVisualChanged,
  });

  final DeviceControlController controller;
  final bool retract;
  final bool Function() isEnabled;
  final bool Function() isActive;
  final void Function(String message) onMessage;
  final void Function() onVisualChanged;

  Timer? _holdTimer;
  Timer? _latchTimer;
  Timer? _pulseTimer;
  bool pressed = false;
  bool _runningFromHold = false;
  bool _latchedFeed = false;

  /// Android `startFeedClick`: hold-run after 500ms, before 3s latch.
  bool get holdingRun => pressed && _runningFromHold && !_latchedFeed;

  /// Android `isContinuousFeed`: latched until tap-to-stop.
  bool get latched => _latchedFeed;

  void dispose() {
    _holdTimer?.cancel();
    _latchTimer?.cancel();
    _pulseTimer?.cancel();
    if (_runningFromHold && !_latchedFeed) {
      unawaited(controller.stopWire());
    }
  }

  void pointerDown() {
    if (!isEnabled()) {
      return;
    }
    if (!retract && isActive()) {
      // Next tap stops latched continuous feed (lws-ui feedTapToStopContinuous).
      pressed = true;
      _runningFromHold = false;
      onVisualChanged();
      return;
    }
    pressed = true;
    _runningFromHold = false;
    _latchedFeed = false;
    _holdTimer = Timer(DeviceControlTiming.wireHoldToRun, () async {
      if (!pressed) {
        return;
      }
      final error = await controller.startWire(retract: retract);
      if (error != null) {
        onMessage(_failureMessage(error));
        return;
      }
      _runningFromHold = true;
      if (!retract) {
        _latchTimer = Timer(
          DeviceControlTiming.wireFeedLatchDelay -
              DeviceControlTiming.wireHoldToRun,
          () {
            if (pressed) {
              _latchedFeed = true;
              onMessage(DeviceControlFeedbackCopy.feedOngoing);
              onVisualChanged();
            }
          },
        );
      }
      onVisualChanged();
    });
    onVisualChanged();
  }

  void pointerUp() {
    if (!pressed) {
      return;
    }
    pressed = false;
    _holdTimer?.cancel();
    _holdTimer = null;
    _latchTimer?.cancel();
    _latchTimer = null;

    if (!isEnabled()) {
      onVisualChanged();
      return;
    }

    if (_runningFromHold) {
      if (!_latchedFeed || retract) {
        // Feed hold release → `feed_successful`; retract hold → `feed_end_text`.
        // Latched feed keeps running until the next tap.
        unawaited(
          _stopWithMessage(
            retract
                ? DeviceControlFeedbackCopy.feedStopped
                : DeviceControlFeedbackCopy.feedPulseSuccess,
          ),
        );
      }
      // Latched: keep `_latchedFeed` / wire running after release.
    } else if (!retract && isActive()) {
      // Tap-to-stop while continuous feed is latched.
      unawaited(_stopLatched());
    } else {
      unawaited(_pulse());
    }
    onVisualChanged();
  }

  Future<void> _stopLatched() async {
    final error = await controller.stopWire();
    if (error != null) {
      onMessage(_failureMessage(error));
      return;
    }
    _latchedFeed = false;
    _runningFromHold = false;
    onMessage(DeviceControlFeedbackCopy.stopFeed);
    onVisualChanged();
  }

  Future<void> _pulse() async {
    final error = await controller.startWire(retract: retract);
    if (error != null) {
      onMessage(_failureMessage(error));
      return;
    }
    onMessage(
      retract
          ? DeviceControlFeedbackCopy.retractPulseSuccess
          : DeviceControlFeedbackCopy.feedPulseSuccess,
    );
    _pulseTimer?.cancel();
    _pulseTimer = Timer(DeviceControlTiming.wirePulseDuration, () {
      unawaited(controller.stopWire());
    });
  }

  Future<void> _stopWithMessage(String message) async {
    final error = await controller.stopWire();
    if (error != null) {
      onMessage(_failureMessage(error));
      return;
    }
    _runningFromHold = false;
    onMessage(message);
  }

  String _failureMessage(LaserEnableBlockReason error) {
    // Wire ops map write failures to the generic lws-ui operation_failed toast.
    if (error == LaserEnableBlockReason.writeFailed) {
      return DeviceControlFeedbackCopy.operationFailed;
    }
    return controller.lastError ?? error.message;
  }
}
