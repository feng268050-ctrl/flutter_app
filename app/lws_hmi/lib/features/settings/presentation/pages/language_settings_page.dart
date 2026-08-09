import 'dart:async';

import 'package:cyber_hal/locale.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = CommonSettingsScope.maybeOf(context);
    return SettingsScaffold(
      title: l10n.languageSettingText,
      body: store == null
          ? SettingsScrollView(
              children: [
                SettingsHelpFooter(l10n.languagePreferenceUnavailable),
              ],
            )
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final lang = store.language;
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
                              unawaited(store.setLanguage(option));
                            },
                          ),
                      ],
                    ),
                    SettingsHelpFooter(l10n.languageAppliesToUi),
                  ],
                );
              },
            ),
    );
  }
}
