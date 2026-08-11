import 'dart:async';

import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:os_settings/app/os_cyber_ime_language_provider.dart';
import 'package:os_settings/app/services.dart';
import 'package:os_settings/audio/hal_click_sound.dart';
import 'package:os_settings/cloud/cloud_settings_store.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/chrome/system_wallpaper_backdrop.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/l10n/app_locales.dart';
import 'package:os_settings/shell/os_settings_shell.dart';

/// Root [MaterialApp] for Platform OS Settings.
class OsSettingsApp extends StatefulWidget {
  const OsSettingsApp({super.key, required this.services});

  final OsSettingsServices services;

  @override
  State<OsSettingsApp> createState() => _OsSettingsAppState();
}

class _OsSettingsAppState extends State<OsSettingsApp> {
  late final HalClickSound _clickSound =
      HalClickSound(widget.services.buttonFeedback());
  late final CyberImeMutableRegionalLayoutProvider _regionalLayout =
      CyberImeMutableRegionalLayoutProvider();
  late final OsCyberImeLanguageProvider _imeLanguage =
      OsCyberImeLanguageProvider(widget.services.locale());
  late final ValueNotifier<double> _uiScaleNotifier =
      ValueNotifier<double>(widget.services.uiScale().scale);
  late final CloudSettingsStore _cloudSettings = CloudSettingsStore()
    ..warmRead();

  @override
  void initState() {
    super.initState();
    _clickSound.warmRead();
    widget.services.wallpaper().warmRead();
    widget.services.uiScale().warmRead();
    unawaited(widget.services.locale().read());
    _uiScaleNotifier.value = widget.services.uiScale().scale;
    CyberClickSoundRegistry.register(_clickSound);
    CyberImeLanguageRegistry.register(_imeLanguage);
    CyberImeRegionalLayoutRegistry.register(_regionalLayout);
    CyberImePhysicalKeyboard.register(
      CyberImeCallbackPhysicalKeyboardDetector(
        () => widget.services.keyboard().isPresent(),
      ),
    );
    unawaited(widget.services.mediaAudio().warmClickSession());
  }

  @override
  void dispose() {
    CyberClickSoundRegistry.register(null);
    CyberImeLanguageRegistry.register(null);
    CyberImeRegionalLayoutRegistry.register(null);
    CyberImePhysicalKeyboard.register(null);
    _uiScaleNotifier.dispose();
    widget.services.wallClock.dispose();
    super.dispose();
  }

  void refreshUiScale() {
    _uiScaleNotifier.value = widget.services.uiScale().scale;
  }

  @override
  Widget build(BuildContext context) {
    final localeSettings = widget.services.locale();
    return OsSettingsScope(
      services: widget.services,
      cloudSettings: _cloudSettings,
      uiScaleNotifier: _uiScaleNotifier,
      onUiScaleChanged: refreshUiScale,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          widget.services.wallClock,
          localeSettings,
        ]),
        builder: (context, _) {
          return MaterialApp(
            title: 'OS Settings',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            locale: localeFromLanguageTag(localeSettings.languageWire),
            supportedLocales: kOsSettingsSupportedLocales,
            localeListResolutionCallback: (locales, supported) {
              final preferred =
                  locales == null || locales.isEmpty ? null : locales.first;
              return resolveOsSettingsLocale(preferred, supported) ??
                  supported.first;
            },
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return ListenableBuilder(
                listenable: Listenable.merge([
                  widget.services.wallClock,
                  _uiScaleNotifier,
                ]),
                builder: (context, _) {
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(
                      alwaysUse24HourFormat:
                          widget.services.wallClock.use24HourFormat,
                    ),
                    child: matchEmbedderDensity(
                      context,
                      SettingsBlurHost(
                        blurSigma: SettingsPerspectiveChrome.blurSigma,
                        backdropBuilder: () => const SystemWallpaperBackdrop(),
                        rebakeListenable: widget.services.wallpaper().listenable,
                        rebakeKey: widget.services.wallpaper().activePath,
                        child: child ?? const SizedBox.shrink(),
                      ),
                      uiScale: _uiScaleNotifier.value,
                    ),
                  );
                },
              );
            },
            home: const OsSettingsShell(),
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: Colors.blueGrey,
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: baseScheme.copyWith(surface: Colors.transparent),
    useMaterial3: true,
    canvasColor: Colors.transparent,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: CyberColors.textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      textColor: CyberColors.textPrimary,
      iconColor: CyberColors.textSecondary,
    ),
    dividerColor: CyberColors.borderMid,
    extensions: const <ThemeExtension<dynamic>>[
      CyberGlassTheme(),
      SettingsTypography(),
    ],
  );
}

/// Provides [OsSettingsServices] to the shell and all pushed pages.
class OsSettingsScope extends InheritedWidget {
  const OsSettingsScope({
    super.key,
    required this.services,
    required this.cloudSettings,
    required this.uiScaleNotifier,
    required this.onUiScaleChanged,
    required super.child,
  });

  final OsSettingsServices services;
  final CloudSettingsStore cloudSettings;
  final ValueNotifier<double> uiScaleNotifier;
  final VoidCallback onUiScaleChanged;

  static OsSettingsServices of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<OsSettingsScope>();
    assert(scope != null, 'OsSettingsScope not found');
    return scope!.services;
  }

  static CloudSettingsStore cloudSettingsOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<OsSettingsScope>();
    assert(scope != null, 'OsSettingsScope not found');
    return scope!.cloudSettings;
  }

  static OsSettingsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OsSettingsScope>();
  }

  @override
  bool updateShouldNotify(OsSettingsScope oldWidget) {
    return services != oldWidget.services ||
        cloudSettings != oldWidget.cloudSettings ||
        uiScaleNotifier != oldWidget.uiScaleNotifier;
  }
}
