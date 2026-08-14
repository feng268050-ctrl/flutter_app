import 'package:flutter/material.dart';

/// Reading vs display / geometry text-scale policy (FrostUI Small/Medium/Large).
///
/// Reading UI uses the ambient [MediaQuery.textScaler] (0.90 / 1.00 / 1.12 when
/// wired). Geometry-bound chrome uses a clamped display scaler so Large does
/// not blow Home clock / gauges. Home Quick Action captions stay at Medium.
abstract final class HmiTextScale {
  static const readingSmall = 0.90;
  static const readingMedium = 1.00;
  static const readingLarge = 1.12;

  static const displaySmall = 0.95;
  static const displayMedium = 1.00;
  static const displayLarge = 1.05;

  /// Class B settings row minHeight multipliers (vs Medium baseline).
  static const settingsRowSmall = 0.95;
  static const settingsRowMedium = 1.00;
  static const settingsRowLarge = 1.12;

  /// Class B primary tab heights (logical px).
  static const tabHeightSmall = 64.0;
  static const tabHeightMedium = 68.0;
  static const tabHeightLarge = 76.0;

  /// Effective linear factor of [scaler] (probes a 100sp run).
  static double factorOf(TextScaler scaler) => scaler.scale(100) / 100;

  static double readingFactorOf(BuildContext context) =>
      factorOf(MediaQuery.textScalerOf(context));

  /// Maps reading factor → display clamp (0.95 / 1.00 / 1.05).
  static double displayFactorForReading(double reading) {
    if (reading <= readingMedium) {
      final t = ((reading - readingSmall) / (readingMedium - readingSmall))
          .clamp(0.0, 1.0);
      return displaySmall + (displayMedium - displaySmall) * t;
    }
    final t = ((reading - readingMedium) / (readingLarge - readingMedium))
        .clamp(0.0, 1.0);
    return displayMedium + (displayLarge - displayMedium) * t;
  }

  static TextScaler displayTextScalerOf(BuildContext context) {
    return TextScaler.linear(
      displayFactorForReading(readingFactorOf(context)),
    );
  }

  /// Settings row minHeight multiplier for the current reading scale.
  static double settingsRowFactorForReading(double reading) {
    if (reading <= readingMedium) {
      final t = ((reading - readingSmall) / (readingMedium - readingSmall))
          .clamp(0.0, 1.0);
      return settingsRowSmall + (settingsRowMedium - settingsRowSmall) * t;
    }
    final t = ((reading - readingMedium) / (readingLarge - readingMedium))
        .clamp(0.0, 1.0);
    return settingsRowMedium + (settingsRowLarge - settingsRowMedium) * t;
  }

  static double settingsRowFactorOf(BuildContext context) =>
      settingsRowFactorForReading(readingFactorOf(context));

  /// Primary tab track height for the current reading scale.
  static double tabHeightForReading(double reading) {
    if (reading <= readingMedium) {
      final t = ((reading - readingSmall) / (readingMedium - readingSmall))
          .clamp(0.0, 1.0);
      return tabHeightSmall + (tabHeightMedium - tabHeightSmall) * t;
    }
    final t = ((reading - readingMedium) / (readingLarge - readingMedium))
        .clamp(0.0, 1.0);
    return tabHeightMedium + (tabHeightLarge - tabHeightMedium) * t;
  }

  static double tabHeightOf(BuildContext context) =>
      tabHeightForReading(readingFactorOf(context));
}

/// Explicit opt-out for product chrome whose label size is frozen at Medium.
///
/// Keep this scope narrow: ordinary reading UI must continue to follow the
/// operator's Small / Medium / Large setting.
final class HmiFixedTextScale extends StatelessWidget {
  const HmiFixedTextScale({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: child,
    );
  }
}
