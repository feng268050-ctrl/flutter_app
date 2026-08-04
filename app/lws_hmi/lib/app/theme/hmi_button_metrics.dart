import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// FrostUI 100% button size ladder (doc §6.1).
enum HmiButtonSize {
  mini,
  small,
  medium,
  large,
  hero,
}

/// Width behavior independent of text size (doc §6.2).
enum HmiButtonWidthPolicy {
  /// Grow with label (+ minWidth floor).
  adaptive,

  /// Same width as siblings in a group (caller supplies [width] or Expanded).
  equal,

  /// Explicit [width].
  fixed,

  /// Occupy parent width (`stretch`).
  fill,
}

/// Layout + typography tokens for one [HmiButtonSize].
@immutable
class HmiButtonMetrics {
  const HmiButtonMetrics({
    required this.height,
    required this.minWidth,
    required this.horizontalPadding,
    required this.iconSize,
    required this.textStyle,
  });

  final double height;
  final double minWidth;
  final double horizontalPadding;
  final double iconSize;
  final TextStyle textStyle;

  /// 100% baseline metrics from [HmiTypography] button roles.
  static HmiButtonMetrics forSize(HmiButtonSize size, HmiTypography typography) {
    return switch (size) {
      HmiButtonSize.mini => HmiButtonMetrics(
          height: 36,
          minWidth: 72,
          horizontalPadding: 12,
          iconSize: 18,
          textStyle: typography.buttonMini,
        ),
      HmiButtonSize.small => HmiButtonMetrics(
          height: 44,
          minWidth: 96,
          horizontalPadding: 16,
          iconSize: 20,
          textStyle: typography.buttonSmall,
        ),
      HmiButtonSize.medium => HmiButtonMetrics(
          height: 52,
          minWidth: 120,
          horizontalPadding: 24,
          iconSize: 24,
          textStyle: typography.buttonMedium,
        ),
      HmiButtonSize.large => HmiButtonMetrics(
          height: 60,
          minWidth: 144,
          horizontalPadding: 28,
          iconSize: 28,
          textStyle: typography.buttonLarge,
        ),
      HmiButtonSize.hero => HmiButtonMetrics(
          height: 72,
          minWidth: 200,
          horizontalPadding: 32,
          iconSize: 32,
          textStyle: typography.buttonHero,
        ),
    };
  }
}
