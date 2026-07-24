import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CommonSettingsScope.maybeOf(context);
    return SettingsScaffold(
      title: 'Language',
      body: store == null
          ? const SettingsScrollView(
              children: [
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Language preference unavailable.',
                    style: TextStyle(color: Colors.white54),
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
                    const SettingsSectionHeader('Language'),
                    SettingsGroup(
                      children: [
                        for (final code in CommonSettingsStore.supportedLanguages)
                          SettingsOptionTile(
                            title: code == CommonSettingsStore.languageEn
                                ? 'English'
                                : '中文',
                            selected: lang == code,
                            onTap: () {
                              unawaited(store.setLanguage(code));
                            },
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Persisted under /var/lib/hmi/common-settings.json. '
                        'Applies to soft keyboard language (CyberIME).',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
