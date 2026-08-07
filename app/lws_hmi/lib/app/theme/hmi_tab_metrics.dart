import 'package:flutter/material.dart';

/// Primary (level-1) top-tab metrics — Settings / Monitor / Engineer.
///
/// Icon + label form one compact group centered in the equal-width / flex cell.
/// Selection only changes color, weight, and the cell-wide indicator.
abstract final class HmiTabMetrics {
  static const double labelFontSize = 24;
  static const FontWeight labelWeight = FontWeight.w500;
  static const FontWeight selectedLabelWeight = FontWeight.w600;

  static const double iconSize = 28;
  static const double iconLabelGap = 8;
  static const double horizontalPadding = 20;

  /// Default strip height for Settings / Monitor / Engineer primary tabs.
  static const double tabHeight = 68;

  static const double indicatorHeight = 2;
}
