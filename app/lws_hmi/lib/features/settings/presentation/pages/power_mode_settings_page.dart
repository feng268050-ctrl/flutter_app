import 'dart:async';

import 'package:cyber_hal/output/load_profile.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/load_profile_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Common Settings → Power Mode (性能 / 均衡). Load / thermal profile, not 省电.
class PowerModeSettingsPage extends StatelessWidget {
  const PowerModeSettingsPage({super.key});

  static String modeLabel(AppLocalizations l10n, LoadProfileMode mode) {
    return switch (mode) {
      LoadProfileMode.performance => l10n.powerModeOptionPerformance,
      LoadProfileMode.balanced => l10n.powerModeOptionBalanced,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = LoadProfileScope.maybeOf(context);
    return SettingsScaffold(
      title: l10n.powerModeSettingText,
      body: controller == null
          ? SettingsScrollView(
              children: [
                SettingsHelpFooter(l10n.powerModePreferenceUnavailable),
              ],
            )
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final mode = controller.mode;
                return SettingsScrollView(
                  children: [
                    SettingsGroup(
                      bottomInset: 0,
                      children: [
                        for (final m in LoadProfileMode.values)
                          SettingsOptionTile(
                            title: modeLabel(l10n, m),
                            selected: mode == m,
                            onTap: () {
                              unawaited(controller.setMode(m));
                            },
                          ),
                      ],
                    ),
                    SettingsHelpFooter(l10n.powerModePersistedFooter),
                  ],
                );
              },
            ),
    );
  }
}
