import 'dart:async';

import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Shared Feed/Retract pointer protocol for Quick and Engineer panels.
///
/// Short press → ~500ms pulse then auto-stop. Hold ≥500ms runs while pressed
/// (release stops). Feed held ~3s total latches continuous feed until the next
/// tap; Retract never latches.
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
    required this.l10n,
  });

  final DeviceControlController controller;
  final bool retract;
  final bool Function() isEnabled;
  final bool Function() isActive;
  final void Function(String message) onMessage;
  final void Function() onVisualChanged;
  final AppLocalizations Function() l10n;

  Timer? _holdTimer;
  Timer? _latchTimer;
  Timer? _pulseTimer;
  bool pressed = false;
  bool _runningFromHold = false;
  bool _latchedFeed = false;
  /// True once the 3s latch window elapsed while still pressed, but
  /// [startWire] has not finished yet — promote as soon as hold-run starts.
  bool _latchDue = false;
  DateTime? _pressStartedAt;

  /// Android `startFeedClick`: hold-run after 500ms, before 3s latch.
  bool get holdingRun => pressed && _runningFromHold && !_latchedFeed;

  /// Android `isContinuousFeed`: latched until tap-to-stop.
  bool get latched => _latchedFeed;

  void dispose() {
    _holdTimer?.cancel();
    _latchTimer?.cancel();
    _pulseTimer?.cancel();
    // Hold-run and latched continuous feed both leave wireWork ON — stop both.
    // (Previously only non-latched hold-run was cleared, so Back→home left
    // continuous feed running until an explicit End of work.)
    if (_latchedFeed || _runningFromHold) {
      _latchedFeed = false;
      _runningFromHold = false;
      unawaited(controller.stopWire());
    }
  }

  /// Enter continuous feed if still holding and wire is already running.
  ///
  /// Called from the 3s timer and from Feed L→R fill completion so the solid
  /// / Continuous Feed chrome cannot race behind a cancelled timer on release.
  void promoteContinuousFeedIfHolding() {
    if (retract || !pressed || _latchedFeed) {
      return;
    }
    if (_runningFromHold) {
      _enterContinuousFeed();
    } else {
      _latchDue = true;
    }
  }

  void _enterContinuousFeed() {
    if (_latchedFeed) {
      return;
    }
    _latchedFeed = true;
    onMessage(DeviceControlFeedbackCopy.feedOngoing(l10n()));
    onVisualChanged();
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
    _latchDue = false;
    _pressStartedAt = DateTime.now();
    // Latch window aligns with Feed L→R fill: 3s from press, not from
    // startWire completion (which would slip past the visual fill).
    if (!retract) {
      _latchTimer = Timer(DeviceControlTiming.wireFeedLatchDelay, () {
        promoteContinuousFeedIfHolding();
      });
    }
    _holdTimer = Timer(DeviceControlTiming.wireHoldToRun, () async {
      if (!pressed) {
        return;
      }
      final error = await controller.startWire(retract: retract);
      if (error != null) {
        _latchTimer?.cancel();
        _latchTimer = null;
        onMessage(_failureMessage(error));
        return;
      }
      if (!pressed) {
        return;
      }
      _runningFromHold = true;
      if (!retract && _latchDue) {
        _enterContinuousFeed();
      } else {
        onVisualChanged();
      }
    });
    onVisualChanged();
  }

  void pointerUp() {
    if (!pressed) {
      return;
    }
    // Promote latch before cancelling the timer: releasing exactly at the 3s
    // mark must keep continuous feed (solid Continuous Feed), not reverse.
    if (!retract &&
        _runningFromHold &&
        !_latchedFeed &&
        _pressStartedAt != null &&
        DateTime.now().difference(_pressStartedAt!) >=
            DeviceControlTiming.wireFeedLatchDelay) {
      _enterContinuousFeed();
    }
    pressed = false;
    _pressStartedAt = null;
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
                ? DeviceControlFeedbackCopy.feedStopped(l10n())
                : DeviceControlFeedbackCopy.feedPulseSuccess(l10n()),
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
    onMessage(DeviceControlFeedbackCopy.stopFeed(l10n()));
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
          ? DeviceControlFeedbackCopy.retractPulseSuccess(l10n())
          : DeviceControlFeedbackCopy.feedPulseSuccess(l10n()),
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
    final loc = l10n();
    // Wire ops map write failures to the generic lws-ui operation_failed toast.
    if (error == LaserEnableBlockReason.writeFailed) {
      return DeviceControlFeedbackCopy.operationFailed(loc);
    }
    return controller.lastError ?? error.localizedMessage(loc);
  }
}
