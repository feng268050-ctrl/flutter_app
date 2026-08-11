import 'dart:async';

import 'package:cyber_hal/locale.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Language — PreferredLanguage in locale.conf.
class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  LocaleSettings? _locale;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_boot());
    });
  }

  Future<void> _boot() async {
    final locale = OsSettingsScope.of(context).locale();
    await locale.read();
    if (!mounted) return;
    setState(() {
      _locale = locale;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = _locale;
    return SettingsScaffold(
      title: l10n.languageSettingText,
      body: !_ready || locale == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: locale,
              builder: (context, _) {
                final lang = locale.language;
                return SettingsScrollView(
                  children: [
                    SettingsGroup(
                      bottomInset: 0,
                      children: [
                        for (final option in PreferredLanguage.supported)
                          SettingsOptionTile(
                            title: option.endonym,
                            selected: lang == option,
                            onTap: () {
                              unawaited(locale.setLanguage(option));
                            },
                          ),
                      ],
                    ),
                    SettingsHelpFooter(l10n.languageSettingHelp),
                  ],
                );
              },
            ),
    );
  }
}
