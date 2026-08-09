import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/app_text_size.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Common Settings → Text Size (Small / Medium / Large).
class TextSizeSettingsPage extends StatelessWidget {
  const TextSizeSettingsPage({super.key});

  static String labelFor(AppLocalizations l10n, AppTextSize size) {
    switch (size) {
      case AppTextSize.small:
        return l10n.textSizeOptionSmall;
      case AppTextSize.large:
        return l10n.textSizeOptionLarge;
      case AppTextSize.medium:
        return l10n.defaultLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = CommonSettingsScope.maybeOf(context);
    return SettingsScaffold(
      title: l10n.textSizeSettingText,
      body: store == null
          ? SettingsScrollView(
              children: [
                SettingsHelpFooter(l10n.textSizePreferenceUnavailable),
              ],
            )
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final selected = store.textSize;
                return SettingsScrollView(
                  children: [
                    SettingsGroup(
                      bottomInset: 0,
                      children: [
                        for (final size
                            in CommonSettingsStore.supportedTextSizes)
                          SettingsOptionTile(
                            title: labelFor(l10n, size),
                            selected: selected == size,
                            onTap: () {
                              unawaited(store.setTextSize(size));
                            },
                          ),
                      ],
                    ),
                    SettingsHelpFooter(l10n.textSizePersistedFooter),
                  ],
                );
              },
            ),
    );
  }
}
