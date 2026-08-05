import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';

/// Stacked ↑ / ↓ beside a temperature: red up = rise, green down = fall.
///
/// Shared by Monitor Alarm metrics and Live Machine Status ("更多监测").
final class TempTrendArrows extends StatelessWidget {
  const TempTrendArrows({
    super.key,
    required this.trend,
    this.upColor = const Color(0xFFFF5A5A),
    this.downColor = const Color(0xFF3DDC84),
    this.idleColor = const Color(0x40FFFFFF),
  });

  final TempTrend trend;
  final Color upColor;
  final Color downColor;
  final Color idleColor;

  /// Matches Live Machine Status `_TempTrendArrows` slot.
  static const size = 22.0;
  static const slotHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: slotHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -6,
            child: Icon(
              Icons.arrow_drop_up,
              size: size,
              color: trend == TempTrend.up ? upColor : idleColor,
            ),
          ),
          Positioned(
            bottom: -6,
            child: Icon(
              Icons.arrow_drop_down,
              size: size,
              color: trend == TempTrend.down ? downColor : idleColor,
            ),
          ),
        ],
      ),
    );
  }
}
