import 'package:flutter/material.dart';

/// FrostUI color tokens (lws-ui `frostui_colors.xml` / `FrostColors`).
abstract final class CyberColors {
  // Panel fill — dark
  static const fillTop = Color(0x73121214);
  static const fillMid = Color(0x7018181A);
  static const fillBottom = Color(0x6E1C1C1E);

  static const fillSolidTop = Color(0xFF121214);
  static const fillSolidMid = Color(0xFF18181A);
  static const fillSolidBottom = Color(0xFF1C1C1E);

  // Panel fill — light
  static const lightFillTop = Color(0x40FFFFFF);
  static const lightFillMid = Color(0x33FFFCFA);
  static const lightFillBottom = Color(0x2EFFF8F6);

  /// LIGHT warn / work-status backdrop (lws-ui `WorkStatusDialogBackdropDrawable`).
  static const lightWarnBackdropEdge = Color(0xB8FFEFD0);
  static const lightWarnBackdropBlend = Color(0xA6FFF8F0);
  static const lightWarnBackdropCenter = Color(0xBFFFFFFF);

  /// LIGHT shell frost veil (lws-ui `WorkStatusDialogShellFrostDrawable`).
  static const lightShellFrostEdge = Color(0x28FFFFFF);
  static const lightShellFrostCenter = Color(0x1FFFFFFF);

  // Panel border — dark
  static const borderHighlight = Color(0x77FFFFFF);
  static const borderMid = Color(0x8868686C);
  static const borderShadow = Color(0x66000000);

  /// Readable uniform stroke on dark HMI when gradient outline is not used.
  static const borderUniform = Color(0xB3FFFFFF);

  /// Tip dialog rim — 1px white highlight at 50% opacity (`0x80`).
  ///
  /// Not solid action orange (`#F46E01`).
  static const tipRimHighlight = Color(0x80FFFFFF);

  /// LIGHT cream dialog container rim — 1px opaque black.
  ///
  /// Warn frost + Engineer / Laser Enable light prompts.
  static const creamDialogRim = Color(0xFF000000);

  /// Home quick-action (Monitor / Settings / AI Vision) flat 1px rim — 30% white.
  ///
  /// Only those three tiles; [CyberButton] uses [buttonRim] instead.
  static const homeQuickActionRim = Color(0x4DFFFFFF);

  /// [CyberButton] standard / secondary / light flat 1px rim — 70% white.
  static const buttonRim = Color(0xB3FFFFFF);

  /// [CyberButtonVariant.primary] flat 1px highlight rim — 60% white.
  static const buttonPrimaryRim = Color(0x99FFFFFF);

  // Panel border — light
  static const lightBorderHighlight = Color(0xD9FFFFFF);
  static const lightBorderMid = Color(0x80E0E0E0);
  static const lightBorderShadow = Color(0x40000000);

  static const blurTintDark = Color(0x30101012);
  static const blurTintWarm = Color(0x52FFFFFF);
  static const scrim = Color(0x99000000);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B8BC);

  /// Frost primary fill (`reminder_confirm_button`).
  static const buttonPrimaryFill = Color(0xFFF37535);

  /// Legacy alias — prefer [buttonPrimaryFill] for solid primary buttons.
  static const buttonPrimaryAccent = Color(0xFFFF8A4D);

  /// Primary button border stops (Frost primary HL / mid / shadow).
  static const buttonPrimaryBorderHighlight = Color(0xE6FFFFF5);
  static const buttonPrimaryBorderMid = Color(0xCCFFC078);
  static const buttonPrimaryBorderShadow = Color(0x99E07040);

  static const buttonSecondaryText = Color(0xFFFF5A52);

  /// Frost section hairline center stop (was mid-gray `0x9968686C` — too soft
  /// on Monitor/Settings frost plates). Matches [borderUniform] opacity.
  static const dividerCenter = Color(0xB3FFFFFF);
}
