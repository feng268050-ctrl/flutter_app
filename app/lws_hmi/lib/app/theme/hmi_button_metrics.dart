import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// FrostUI 100% button size ladder (doc §6.1).
enum HmiButtonSize {
  mini,
  small,
  medium,
  large,
  hero,
  jumbo,
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
///
/// Layout numbers ([height], [minWidth], [horizontalPadding], [iconSize]) are
/// the single source of truth for the ladder — including specialty chrome that
/// is **not** an [HmiButton] (Quick/Engineer wire ops). Prefer
/// `HmiButtonMetrics.*.Height` / `*IconSize` over copying literals.
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

  // --- Layout ladder (SoT) -------------------------------------------------

  static const miniHeight = 36.0;
  static const miniMinWidth = 72.0;
  static const miniPaddingHorizontal = 12.0;
  static const miniIconSize = 18.0;

  static const smallHeight = 44.0;
  static const smallMinWidth = 96.0;
  static const smallPaddingHorizontal = 16.0;
  static const smallIconSize = 20.0;

  static const mediumHeight = 52.0;
  static const mediumMinWidth = 120.0;
  static const mediumPaddingHorizontal = 24.0;
  static const mediumIconSize = 24.0;

  static const largeHeight = 60.0;
  static const largeMinWidth = 144.0;
  static const largePaddingHorizontal = 28.0;
  static const largeIconSize = 28.0;

  static const heroHeight = 68.0;
  static const heroMinWidth = 200.0;
  static const heroPaddingHorizontal = 32.0;
  static const heroIconSize = 32.0;

  static const jumboHeight = 88.0;
  static const jumboMinWidth = 240.0;
  static const jumboPaddingHorizontal = 36.0;
  static const jumboIconSize = 36.0;

  /// 100% baseline metrics from [HmiTypography] button roles.
  static HmiButtonMetrics forSize(HmiButtonSize size, HmiTypography typography) {
    return switch (size) {
      HmiButtonSize.mini => HmiButtonMetrics(
          height: miniHeight,
          minWidth: miniMinWidth,
          horizontalPadding: miniPaddingHorizontal,
          iconSize: miniIconSize,
          textStyle: typography.buttonMini,
        ),
      HmiButtonSize.small => HmiButtonMetrics(
          height: smallHeight,
          minWidth: smallMinWidth,
          horizontalPadding: smallPaddingHorizontal,
          iconSize: smallIconSize,
          textStyle: typography.buttonSmall,
        ),
      HmiButtonSize.medium => HmiButtonMetrics(
          height: mediumHeight,
          minWidth: mediumMinWidth,
          horizontalPadding: mediumPaddingHorizontal,
          iconSize: mediumIconSize,
          textStyle: typography.buttonMedium,
        ),
      HmiButtonSize.large => HmiButtonMetrics(
          height: largeHeight,
          minWidth: largeMinWidth,
          horizontalPadding: largePaddingHorizontal,
          iconSize: largeIconSize,
          textStyle: typography.buttonLarge,
        ),
      HmiButtonSize.hero => HmiButtonMetrics(
          height: heroHeight,
          minWidth: heroMinWidth,
          horizontalPadding: heroPaddingHorizontal,
          iconSize: heroIconSize,
          textStyle: typography.buttonHero,
        ),
      HmiButtonSize.jumbo => HmiButtonMetrics(
          height: jumboHeight,
          minWidth: jumboMinWidth,
          horizontalPadding: jumboPaddingHorizontal,
          iconSize: jumboIconSize,
          textStyle: typography.buttonJumbo,
        ),
    };
  }
}
