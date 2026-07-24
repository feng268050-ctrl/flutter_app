import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  static String _endonym(String code) {
    switch (code) {
      case CommonSettingsStore.languageZhCn:
        return '简体中文';
      case CommonSettingsStore.languageZhTw:
        return '繁體中文';
      case CommonSettingsStore.languageEnUs:
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = CommonSettingsScope.maybeOf(context);
    return SettingsScaffold(
      title: l10n.languageSettingText,
      body: store == null
          ? SettingsScrollView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.languagePreferenceUnavailable,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final lang = store.language;
                return SettingsScrollView(
                  children: [
                    SettingsSectionHeader(l10n.languageSettingText),
                    SettingsGroup(
                      children: [
                        for (final code
                            in CommonSettingsStore.supportedLanguages)
                          SettingsOptionTile(
                            title: _endonym(code),
                            selected: lang == code,
                            onTap: () {
                              unawaited(store.setLanguage(code));
                            },
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        l10n.languageAppliesToUi,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
