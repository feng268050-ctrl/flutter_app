import 'package:flutter/material.dart';

/// Business-only display sizes that stay outside the general token ladder
/// (home clock, large gauges, process wheels, etc.).
///
/// No [TextStyle.fontFamily] — Flutter / platform default only.
/// Prefer [TextStyle] tokens; use `*Size` doubles in `const` contexts.
abstract final class HmiDisplayTypography {
  static const double clockSize = 120;
  static const double dashboardValueSize = 68;

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
}
