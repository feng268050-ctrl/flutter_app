import 'package:flutter/material.dart';

/// Business-only display sizes that stay outside the general token ladder
/// (home clock, large gauges, process wheels, etc.).
///
/// No [TextStyle.fontFamily] — Flutter / platform default only.
/// Prefer [TextStyle] tokens; use `*Size` doubles in `const` contexts.
///
/// User text-size scaling for these glyphs is **clamped** via
/// [HmiTextScale.displayTextScalerOf] / [HmiTextScale.displayFactorForReading]
/// (not the full reading 0.90/1.00/1.12 factor).
abstract final class HmiDisplayTypography {
  static const double clockSize = 120;
  static const double dashboardValueSize = 68;
  static const double gaugeValueSize = 46;
  static const double gaugeUnitSize = 18;
  static const double gaugeNameSize = 22;
  static const double gaugeTickLabelSize = 16;

  static const clock = TextStyle(
    fontSize: clockSize,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const dashboardValue = TextStyle(
    fontSize: dashboardValueSize,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Integrated-ring machine-status gauge roles at the 260px baseline.
  /// Gauge widgets apply one shared geometry scale to these four roles.
  static const gaugeValue = TextStyle(
    fontSize: gaugeValueSize,
    fontWeight: FontWeight.w700,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const gaugeUnit = TextStyle(
    fontSize: gaugeUnitSize,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  static const gaugeName = TextStyle(
    fontSize: gaugeNameSize,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  static const gaugeTickLabel = TextStyle(
    fontSize: gaugeTickLabelSize,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
