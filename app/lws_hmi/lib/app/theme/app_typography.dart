import 'package:flutter/material.dart';

/// Project-level semantic text styles (FrostUI english-first typography).
///
/// No [TextStyle.fontFamily] — always use the Flutter / platform default font.
///
/// Prefer [TextStyle] tokens via `AppTypography.control.copyWith(...)`.
/// Use the `*Size` doubles when only a numeric size is needed in a `const`
/// context (`TextStyle.fontSize` is not a constant expression).
abstract final class AppTypography {
  static const double microSize = 12;
  static const double captionSize = 14;
  static const double supportingSize = 16;
  static const double bodySize = 18;
  static const double controlSize = 20;
  static const double sectionTitleSize = 22;
  static const double navigationSize = 24;
  static const double pageTitleSize = 28;
  static const double dialogTitleSize = 32;
  static const double largeDialogTitleSize = 36;
  static const double displaySize = 44;
  static const double criticalTitleSize = 52;
  static const double metricValueSize = 28;

  static const micro = TextStyle(
    fontSize: microSize,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );

  static const caption = TextStyle(
    fontSize: captionSize,
    fontWeight: FontWeight.w400,
    height: 1.30,
  );

  static const supporting = TextStyle(
    fontSize: supportingSize,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const body = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const control = TextStyle(
    fontSize: controlSize,
    fontWeight: FontWeight.w500,
    height: 1.20,
  );

  static const sectionTitle = TextStyle(
    fontSize: sectionTitleSize,
    fontWeight: FontWeight.w500,
    height: 1.20,
  );

  static const navigation = TextStyle(
    fontSize: navigationSize,
    fontWeight: FontWeight.w500,
    height: 1.10,
  );

  static const pageTitle = TextStyle(
    fontSize: pageTitleSize,
    fontWeight: FontWeight.w500,
    height: 1.15,
  );

  static const dialogTitle = TextStyle(
    fontSize: dialogTitleSize,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static const largeDialogTitle = TextStyle(
    fontSize: largeDialogTitleSize,
    fontWeight: FontWeight.w600,
    height: 1.10,
  );

  static const display = TextStyle(
    fontSize: displaySize,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );

  static const criticalTitle = TextStyle(
    fontSize: criticalTitleSize,
    fontWeight: FontWeight.w700,
    height: 1.05,
  );

  /// Monitor / Settings metric values — tabular figures, default family.
  static const metricValue = TextStyle(
    fontSize: metricValueSize,
    fontWeight: FontWeight.w500,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Descending FrostUI size ladder (largest → smallest).
  static const sizeLadder = <double>[
    criticalTitleSize,
    displaySize,
    largeDialogTitleSize,
    dialogTitleSize,
    pageTitleSize,
    navigationSize,
    sectionTitleSize,
    controlSize,
    bodySize,
    supportingSize,
    captionSize,
    microSize,
  ];

  /// Tip body under a divided title — one ladder step below [titleSize], never
  /// larger than the title itself.
  static double tipBodySizeForTitle(double titleSize) {
    for (var i = 0; i < sizeLadder.length; i++) {
      if (titleSize + 0.01 >= sizeLadder[i]) {
        final next = i + 1 < sizeLadder.length ? sizeLadder[i + 1] : sizeLadder[i];
        return next < titleSize ? next : titleSize;
      }
    }
    return microSize < titleSize ? microSize : titleSize;
  }
}
