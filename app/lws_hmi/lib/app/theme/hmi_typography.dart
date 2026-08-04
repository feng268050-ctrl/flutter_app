import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Role-oriented text styles exposed via [ThemeData.extensions].
@immutable
class HmiTypography extends ThemeExtension<HmiTypography> {
  const HmiTypography({
    this.cardTitle = AppTypography.sectionTitle,
    this.metricLabel = AppTypography.control,
    this.metricValue = AppTypography.metricValue,
    this.button = AppTypography.control,
    this.alarmTitle = AppTypography.criticalTitle,
    this.dialogTitle = AppTypography.dialogTitle,
    this.pageTitle = AppTypography.pageTitle,
    this.navigation = AppTypography.navigation,
    this.body = AppTypography.body,
    this.supporting = AppTypography.supporting,
    this.caption = AppTypography.caption,
  });

  final TextStyle cardTitle;
  final TextStyle metricLabel;
  final TextStyle metricValue;
  final TextStyle button;
  final TextStyle alarmTitle;
  final TextStyle dialogTitle;
  final TextStyle pageTitle;
  final TextStyle navigation;
  final TextStyle body;
  final TextStyle supporting;
  final TextStyle caption;

  @override
  HmiTypography copyWith({
    TextStyle? cardTitle,
    TextStyle? metricLabel,
    TextStyle? metricValue,
    TextStyle? button,
    TextStyle? alarmTitle,
    TextStyle? dialogTitle,
    TextStyle? pageTitle,
    TextStyle? navigation,
    TextStyle? body,
    TextStyle? supporting,
    TextStyle? caption,
  }) {
    return HmiTypography(
      cardTitle: cardTitle ?? this.cardTitle,
      metricLabel: metricLabel ?? this.metricLabel,
      metricValue: metricValue ?? this.metricValue,
      button: button ?? this.button,
      alarmTitle: alarmTitle ?? this.alarmTitle,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      pageTitle: pageTitle ?? this.pageTitle,
      navigation: navigation ?? this.navigation,
      body: body ?? this.body,
      supporting: supporting ?? this.supporting,
      caption: caption ?? this.caption,
    );
  }

  @override
  HmiTypography lerp(HmiTypography? other, double t) {
    if (other == null) return this;
    return HmiTypography(
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      metricLabel: TextStyle.lerp(metricLabel, other.metricLabel, t)!,
      metricValue: TextStyle.lerp(metricValue, other.metricValue, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      alarmTitle: TextStyle.lerp(alarmTitle, other.alarmTitle, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      pageTitle: TextStyle.lerp(pageTitle, other.pageTitle, t)!,
      navigation: TextStyle.lerp(navigation, other.navigation, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      supporting: TextStyle.lerp(supporting, other.supporting, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}

extension HmiTypographyX on BuildContext {
  HmiTypography get hmiTypography =>
      Theme.of(this).extension<HmiTypography>() ?? const HmiTypography();
}
