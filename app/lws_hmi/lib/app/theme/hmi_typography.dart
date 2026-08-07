import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Role-oriented text styles for FrostUI 100% baseline ([ThemeExtension]).
///
/// Business pages should pick semantic roles from here (or via components that
/// already bind them). Prefer not to read [AppTypography] `*Size` outside
/// `lib/app/theme/` and specialty painters / large metrics.
@immutable
class HmiTypography extends ThemeExtension<HmiTypography> {
  const HmiTypography({
    // Page and content
    this.pageTitle = AppTypography.pageTitle,
    this.sectionTitle = AppTypography.sectionTitle,
    this.settingsRowTitle = AppTypography.control,
    this.settingsRowValue = AppTypography.control,
    this.body = AppTypography.body,
    this.supporting = AppTypography.supporting,
    this.caption = AppTypography.caption,
    this.technicalMeta = AppTypography.micro,

    // Tabs
    this.primaryTabLabel = AppTypography.navigation,
    this.processTabLabel = AppTypography.control,
    this.secondaryTabLabel = AppTypography.body,
    this.compactTabLabel = AppTypography.supporting,

    // Buttons (w600 unless noted)
    this.buttonMini = _buttonMini,
    this.buttonSmall = _buttonSmall,
    this.buttonMedium = _buttonMedium,
    this.buttonLarge = _buttonLarge,
    this.buttonHero = _buttonHero,
    this.buttonJumbo = _buttonJumbo,
    this.processAction = _processAction,
    this.displayAction = _displayAction,

    // Data
    this.metricLabel = AppTypography.control,
    this.metricValue = AppTypography.metricValue,
    this.metricUnit = AppTypography.supporting,
    this.dashboardValue = _dashboardValue,
    this.clock = _clock,
    this.statusBarLabel = AppTypography.control,
    this.statusBarAction = AppTypography.navigation,

    // Dialogs
    this.dialogTitle = AppTypography.dialogTitle,
    this.importantDialogTitle = AppTypography.largeDialogTitle,
    this.criticalTitle = AppTypography.criticalTitle,
    this.criticalBody = AppTypography.pageTitle,

    // Legacy aliases (map onto semantic roles)
    this.cardTitle = AppTypography.sectionTitle,
    this.button = AppTypography.control,
    this.alarmTitle = AppTypography.criticalTitle,
    this.navigation = AppTypography.navigation,
  });

  static const _buttonMini = TextStyle(
    fontSize: AppTypography.captionSize,
    fontWeight: FontWeight.w600,
    height: 1.20,
  );
  static const _buttonSmall = TextStyle(
    fontSize: AppTypography.supportingSize,
    fontWeight: FontWeight.w600,
    height: 1.20,
  );
  static const _buttonMedium = TextStyle(
    fontSize: AppTypography.controlSize,
    fontWeight: FontWeight.w600,
    height: 1.20,
  );
  static const _buttonLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.20,
  );
  static const _buttonHero = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.10,
  );
  static const _buttonJumbo = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.10,
  );
  static const _processAction = TextStyle(
    fontSize: AppTypography.sectionTitleSize,
    fontWeight: FontWeight.w600,
    height: 1.20,
  );
  static const _displayAction = TextStyle(
    fontSize: AppTypography.displaySize,
    fontWeight: FontWeight.w600,
    height: 1.05,
  );
  static const _dashboardValue = TextStyle(
    fontSize: 68,
    fontWeight: FontWeight.w500,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const _clock = TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.w500,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Page and content
  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle settingsRowTitle;
  final TextStyle settingsRowValue;
  final TextStyle body;
  final TextStyle supporting;
  final TextStyle caption;
  final TextStyle technicalMeta;

  // Tabs
  final TextStyle primaryTabLabel;
  final TextStyle processTabLabel;
  final TextStyle secondaryTabLabel;
  final TextStyle compactTabLabel;

  // Buttons
  final TextStyle buttonMini;
  final TextStyle buttonSmall;
  final TextStyle buttonMedium;
  final TextStyle buttonLarge;
  final TextStyle buttonHero;
  final TextStyle buttonJumbo;
  final TextStyle processAction;
  final TextStyle displayAction;

  // Data
  final TextStyle metricLabel;
  final TextStyle metricValue;
  final TextStyle metricUnit;
  final TextStyle dashboardValue;
  final TextStyle clock;
  final TextStyle statusBarLabel;
  final TextStyle statusBarAction;

  // Dialogs
  final TextStyle dialogTitle;
  final TextStyle importantDialogTitle;
  final TextStyle criticalTitle;
  final TextStyle criticalBody;

  // Legacy
  final TextStyle cardTitle;
  final TextStyle button;
  final TextStyle alarmTitle;
  final TextStyle navigation;

  @override
  HmiTypography copyWith({
    TextStyle? pageTitle,
    TextStyle? sectionTitle,
    TextStyle? settingsRowTitle,
    TextStyle? settingsRowValue,
    TextStyle? body,
    TextStyle? supporting,
    TextStyle? caption,
    TextStyle? technicalMeta,
    TextStyle? primaryTabLabel,
    TextStyle? processTabLabel,
    TextStyle? secondaryTabLabel,
    TextStyle? compactTabLabel,
    TextStyle? buttonMini,
    TextStyle? buttonSmall,
    TextStyle? buttonMedium,
    TextStyle? buttonLarge,
    TextStyle? buttonHero,
    TextStyle? buttonJumbo,
    TextStyle? processAction,
    TextStyle? displayAction,
    TextStyle? metricLabel,
    TextStyle? metricValue,
    TextStyle? metricUnit,
    TextStyle? dashboardValue,
    TextStyle? clock,
    TextStyle? statusBarLabel,
    TextStyle? statusBarAction,
    TextStyle? dialogTitle,
    TextStyle? importantDialogTitle,
    TextStyle? criticalTitle,
    TextStyle? criticalBody,
    TextStyle? cardTitle,
    TextStyle? button,
    TextStyle? alarmTitle,
    TextStyle? navigation,
  }) {
    return HmiTypography(
      pageTitle: pageTitle ?? this.pageTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      settingsRowTitle: settingsRowTitle ?? this.settingsRowTitle,
      settingsRowValue: settingsRowValue ?? this.settingsRowValue,
      body: body ?? this.body,
      supporting: supporting ?? this.supporting,
      caption: caption ?? this.caption,
      technicalMeta: technicalMeta ?? this.technicalMeta,
      primaryTabLabel: primaryTabLabel ?? this.primaryTabLabel,
      processTabLabel: processTabLabel ?? this.processTabLabel,
      secondaryTabLabel: secondaryTabLabel ?? this.secondaryTabLabel,
      compactTabLabel: compactTabLabel ?? this.compactTabLabel,
      buttonMini: buttonMini ?? this.buttonMini,
      buttonSmall: buttonSmall ?? this.buttonSmall,
      buttonMedium: buttonMedium ?? this.buttonMedium,
      buttonLarge: buttonLarge ?? this.buttonLarge,
      buttonHero: buttonHero ?? this.buttonHero,
      buttonJumbo: buttonJumbo ?? this.buttonJumbo,
      processAction: processAction ?? this.processAction,
      displayAction: displayAction ?? this.displayAction,
      metricLabel: metricLabel ?? this.metricLabel,
      metricValue: metricValue ?? this.metricValue,
      metricUnit: metricUnit ?? this.metricUnit,
      dashboardValue: dashboardValue ?? this.dashboardValue,
      clock: clock ?? this.clock,
      statusBarLabel: statusBarLabel ?? this.statusBarLabel,
      statusBarAction: statusBarAction ?? this.statusBarAction,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      importantDialogTitle: importantDialogTitle ?? this.importantDialogTitle,
      criticalTitle: criticalTitle ?? this.criticalTitle,
      criticalBody: criticalBody ?? this.criticalBody,
      cardTitle: cardTitle ?? this.cardTitle,
      button: button ?? this.button,
      alarmTitle: alarmTitle ?? this.alarmTitle,
      navigation: navigation ?? this.navigation,
    );
  }

  @override
  HmiTypography lerp(HmiTypography? other, double t) {
    if (other == null) return this;
    TextStyle L(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return HmiTypography(
      pageTitle: L(pageTitle, other.pageTitle),
      sectionTitle: L(sectionTitle, other.sectionTitle),
      settingsRowTitle: L(settingsRowTitle, other.settingsRowTitle),
      settingsRowValue: L(settingsRowValue, other.settingsRowValue),
      body: L(body, other.body),
      supporting: L(supporting, other.supporting),
      caption: L(caption, other.caption),
      technicalMeta: L(technicalMeta, other.technicalMeta),
      primaryTabLabel: L(primaryTabLabel, other.primaryTabLabel),
      processTabLabel: L(processTabLabel, other.processTabLabel),
      secondaryTabLabel: L(secondaryTabLabel, other.secondaryTabLabel),
      compactTabLabel: L(compactTabLabel, other.compactTabLabel),
      buttonMini: L(buttonMini, other.buttonMini),
      buttonSmall: L(buttonSmall, other.buttonSmall),
      buttonMedium: L(buttonMedium, other.buttonMedium),
      buttonLarge: L(buttonLarge, other.buttonLarge),
      buttonHero: L(buttonHero, other.buttonHero),
      buttonJumbo: L(buttonJumbo, other.buttonJumbo),
      processAction: L(processAction, other.processAction),
      displayAction: L(displayAction, other.displayAction),
      metricLabel: L(metricLabel, other.metricLabel),
      metricValue: L(metricValue, other.metricValue),
      metricUnit: L(metricUnit, other.metricUnit),
      dashboardValue: L(dashboardValue, other.dashboardValue),
      clock: L(clock, other.clock),
      statusBarLabel: L(statusBarLabel, other.statusBarLabel),
      statusBarAction: L(statusBarAction, other.statusBarAction),
      dialogTitle: L(dialogTitle, other.dialogTitle),
      importantDialogTitle: L(importantDialogTitle, other.importantDialogTitle),
      criticalTitle: L(criticalTitle, other.criticalTitle),
      criticalBody: L(criticalBody, other.criticalBody),
      cardTitle: L(cardTitle, other.cardTitle),
      button: L(button, other.button),
      alarmTitle: L(alarmTitle, other.alarmTitle),
      navigation: L(navigation, other.navigation),
    );
  }
}

extension HmiTypographyX on BuildContext {
  HmiTypography get hmiTypography =>
      Theme.of(this).extension<HmiTypography>() ?? const HmiTypography();
}
