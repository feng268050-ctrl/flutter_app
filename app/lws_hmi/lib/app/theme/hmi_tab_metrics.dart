import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/app/theme/hmi_text_scale.dart';

/// Primary (level-1) top-tab **layout** metrics — Settings / Monitor / Engineer.
///
/// Label font size SoT is [HmiTypography.primaryTabLabel] /
/// [AppTypography.navigationSize]. This class owns geometry only.
///
/// Icon + label form one compact group centered in the equal-width / flex cell.
/// Selection only changes color, weight, and the cell-wide indicator.
abstract final class HmiTabMetrics {
  /// Deprecated alias of [AppTypography.navigationSize] for const call sites.
  /// Prefer `context.hmiTypography.primaryTabLabel` when painting.
  static const double labelFontSize = AppTypography.navigationSize;
  static const FontWeight labelWeight = FontWeight.w500;
  static const FontWeight selectedLabelWeight = FontWeight.w600;

  static const double iconSize = 28;
  static const double iconLabelGap = 8;
  static const double horizontalPadding = 20;

  /// Default strip height for Settings / Monitor / Engineer primary tabs
  /// (Medium baseline). Prefer [tabHeightOf] under Small/Large.
  static const double tabHeight = 68;

  static double tabHeightOf(BuildContext context) =>
      HmiTextScale.tabHeightOf(context);

  static const double indicatorHeight = 2;
}
