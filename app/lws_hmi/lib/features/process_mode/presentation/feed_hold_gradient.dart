import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';

/// Feed hold / continuous-feed gradient math (lws-ui `GradientButton` zoom).
///
/// Kept for unit tests / reference; Quick side ops reuse Engineer outline
/// chrome ([ProcessModeOutlineButton]) and no longer paint this band live.
abstract final class FeedHoldGradient {
  /// First-appear mid-band width (hold-run / latch min).
  static const double initialMidWidth = 18;

  /// Hold-run window: 3s latch minus 500ms hold-to-run.
  static final Duration holdExpandDuration =
      DeviceControlTiming.wireFeedLatchDelay -
          DeviceControlTiming.wireHoldToRun;

  /// Android `animation_duration` while `isContinuousFeed`.
  static const Duration latchBreathDuration = Duration(milliseconds: 3000);

  /// Hold one-shot: breath 0→1 ⇒ mid 18px → full width.
  /// Latch breathe: breath 0↔1 ⇒ mid 18px ↔ full width.
  static double breathValue({
    required String? phase,
    required DateTime? holdExpandStartedAt,
    required DateTime? latchBreathStartedAt,
    required double latchBreathPhaseOffset,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (phase == 'holding') {
      final start = holdExpandStartedAt;
      if (start == null) {
        return 0;
      }
      final total = holdExpandDuration.inMilliseconds;
      if (total <= 0) {
        return 1;
      }
      final ms = clock.difference(start).inMilliseconds;
      return (ms / total).clamp(0.0, 1.0);
    }
    if (phase == 'latched') {
      final start = latchBreathStartedAt;
      if (start == null) {
        return 0;
      }
      final period = latchBreathDuration.inMilliseconds;
      if (period <= 0) {
        return 0;
      }
      final phaseT =
          ((clock.difference(start).inMilliseconds / period) +
                  latchBreathPhaseOffset) %
              1.0;
      return phaseT <= 0.5 ? phaseT * 2 : (1 - phaseT) * 2;
    }
    return 0;
  }

  /// Visible mid-band width for [paintWidth] at [breathValue] (0=narrow, 1=full).
  static double midWidth({
    required double paintWidth,
    required double breathValue,
  }) {
    if (paintWidth <= 0) {
      return 0;
    }
    final t = breathValue.clamp(0.0, 1.0);
    final minW = initialMidWidth.clamp(0.0, paintWidth);
    return minW + (paintWidth - minW) * t;
  }

  /// Shrink from absolute mid width: `(1 - mid/paintWidth) / 2`.
  static double shrinkRatio({
    required double paintWidth,
    required double midWidth,
  }) {
    if (paintWidth <= 0) {
      return 0.5;
    }
    final mid = midWidth.clamp(0.0, paintWidth);
    return ((1.0 - mid / paintWidth) / 2.0).clamp(0.0, 0.5);
  }

  static LinearGradient gradient({
    required Color mid,
    required double shrinkRatio,
  }) {
    final shrink = shrinkRatio.clamp(0.0, 0.5);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0x00000000),
        mid,
        const Color(0x00000000),
      ],
      stops: [shrink, 0.5, 1.0 - shrink],
    );
  }
}
