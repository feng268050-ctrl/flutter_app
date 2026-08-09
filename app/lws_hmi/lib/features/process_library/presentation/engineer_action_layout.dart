import 'dart:math' as math;

import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';

/// Responsive geometry for Engineer Mode's Reset / Save action group.
abstract final class EngineerActionLayout {
  /// Compact only this constrained action group; standard Large buttons keep
  /// their normal 28dp content padding elsewhere.
  static const horizontalPadding = 20.0;
  static const groupGap = 12.0;
  static const iconLabelGap = 8.0;

  static double buttonWidthForLabel(double labelWidth) => math.max(
        HmiButtonMetrics.largeMinWidth,
        horizontalPadding * 2 +
            HmiButtonMetrics.largeIconSize +
            iconLabelGap +
            labelWidth,
      );

  /// Large text uses a vertical group only after the two full-size actions no
  /// longer fit side-by-side. The text and icon metrics are never compressed.
  static bool useVertical({
    required bool isLargeText,
    required double maxWidth,
    required double resetLabelWidth,
    required double saveLabelWidth,
  }) =>
      isLargeText &&
      buttonWidthForLabel(resetLabelWidth) +
              groupGap +
              buttonWidthForLabel(saveLabelWidth) >
          maxWidth;
}
