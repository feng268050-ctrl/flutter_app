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

  // Panel border — dark
  static const borderHighlight = Color(0x77FFFFFF);
  static const borderMid = Color(0x8868686C);
  static const borderShadow = Color(0x66000000);

  // Panel border — light
  static const lightBorderHighlight = Color(0xD9FFFFFF);
  static const lightBorderMid = Color(0x80E0E0E0);
  static const lightBorderShadow = Color(0x40000000);

  static const blurTintDark = Color(0x30101012);
  static const blurTintWarm = Color(0x52FFFFFF);
  static const scrim = Color(0x99000000);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B8BC);

  static const buttonPrimaryAccent = Color(0xFFFF8A4D);
  static const buttonSecondaryText = Color(0xFFFF5A52);

  static const dividerCenter = Color(0x9968686C);
}
