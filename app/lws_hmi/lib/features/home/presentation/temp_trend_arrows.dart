import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';

/// Fixed-width ↑ / ↓ slot after a temperature value.
///
/// Always reserves [slotWidth] so the value does not shift when [trend] is
/// [TempTrend.none]. Red up = rise, green down = fall.
/// Shared by Monitor Alarm metrics and Live Machine Status ("更多监测").
final class TempTrendArrows extends StatelessWidget {
  const TempTrendArrows({
    super.key,
    required this.trend,
    this.upColor = const Color(0xFFFF5A5A),
    this.downColor = const Color(0xFF3DDC84),
    this.iconSize = defaultSize,
  });

  final TempTrend trend;
  final Color upColor;
  final Color downColor;
  final double iconSize;

  /// Glyph size (Material drop arrows include internal padding).
  static const defaultSize = 28.0;

  /// Reserved width after the value — keeps layout stable with/without a trend.
  static const slotWidth = 18.0;

  /// Row height for vertical centering with the value.
  static const slotHeight = 28.0;

  /// Alias for [defaultSize] (tests / call sites).
  static const size = defaultSize;

  @override
  Widget build(BuildContext context) {
    final Widget? glyph;
    if (trend == TempTrend.up) {
      glyph = Icon(
        Icons.arrow_drop_up,
        size: iconSize,
        color: upColor,
      );
    } else if (trend == TempTrend.down) {
      glyph = Icon(
        Icons.arrow_drop_down,
        size: iconSize,
        color: downColor,
      );
    } else {
      glyph = null;
    }

    // Fixed slot; OverflowBox lets the padded Material icon sit tight to the
    // value without expanding the reserved width.
    return SizedBox(
      width: slotWidth,
      height: slotHeight,
      child: glyph == null
          ? null
          : Center(
              child: OverflowBox(
                minWidth: 0,
                maxWidth: iconSize,
                minHeight: 0,
                maxHeight: iconSize,
                alignment: Alignment.centerLeft,
                child: glyph,
              ),
            ),
    );
  }
}
