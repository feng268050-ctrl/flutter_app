import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

import 'settings_dimens.dart';

/// Settings list row typography — title and trailing value share control size;
/// differentiation is color (HMI / OS Settings parity).
@immutable
class SettingsTypography extends ThemeExtension<SettingsTypography> {
  const SettingsTypography({
    this.rowTitle = const TextStyle(
      fontSize: SettingsDimens.titleSize,
      fontWeight: FontWeight.w500,
      color: CyberColors.textPrimary,
      height: 1.25,
    ),
    this.rowValue = const TextStyle(
      fontSize: SettingsDimens.titleSize,
      fontWeight: FontWeight.w500,
      color: CyberColors.textSecondary,
      height: 1.25,
    ),
    this.rowMinHeight = SettingsDimens.rowMinHeight,
  });

  final TextStyle rowTitle;
  final TextStyle rowValue;
  final double rowMinHeight;

  static SettingsTypography of(BuildContext context) {
    return Theme.of(context).extension<SettingsTypography>() ??
        const SettingsTypography();
  }

  @override
  SettingsTypography copyWith({
    TextStyle? rowTitle,
    TextStyle? rowValue,
    double? rowMinHeight,
  }) {
    return SettingsTypography(
      rowTitle: rowTitle ?? this.rowTitle,
      rowValue: rowValue ?? this.rowValue,
      rowMinHeight: rowMinHeight ?? this.rowMinHeight,
    );
  }

  @override
  SettingsTypography lerp(SettingsTypography? other, double t) {
    if (other == null) {
      return this;
    }
    return SettingsTypography(
      rowTitle: TextStyle.lerp(rowTitle, other.rowTitle, t) ?? rowTitle,
      rowValue: TextStyle.lerp(rowValue, other.rowValue, t) ?? rowValue,
      rowMinHeight: rowMinHeight + (other.rowMinHeight - rowMinHeight) * t,
    );
  }
}
