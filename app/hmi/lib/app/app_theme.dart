import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    pageTransitionsTheme: kAppPageTransitionsTheme,
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
    ),
    extensions: const <ThemeExtension<dynamic>>[
      CyberGlassTheme(),
    ],
  );
}
