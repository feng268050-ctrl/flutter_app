import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    // No fontFamily — Flutter / platform default for all text.
    textTheme: const TextTheme(
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.supporting,
      bodySmall: AppTypography.caption,
      titleMedium: AppTypography.control,
      titleLarge: AppTypography.sectionTitle,
      headlineSmall: AppTypography.pageTitle,
      headlineMedium: AppTypography.dialogTitle,
      labelLarge: AppTypography.control,
      labelMedium: AppTypography.supporting,
      labelSmall: AppTypography.caption,
    ),
    pageTransitionsTheme: kAppPageTransitionsTheme,
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      CyberGlassTheme(),
      HmiTypography(),
    ],
  );
}
