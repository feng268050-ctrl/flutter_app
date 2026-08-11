import 'dart:async';

import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/cloud/cloud_environment_tier.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Cloud API environment — production (default) or test.
class CloudEnvironmentPage extends StatelessWidget {
  const CloudEnvironmentPage({super.key});

  String _label(AppLocalizations l10n, CloudEnvironmentTier tier) =>
      switch (tier) {
        CloudEnvironmentTier.prod => l10n.cloudEnvironmentTierProd,
        CloudEnvironmentTier.test => l10n.cloudEnvironmentTierTest,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = OsSettingsScope.cloudSettingsOf(context);
    store.warmRead();
    return SettingsScaffold(
      title: l10n.cloudEnvironmentTier,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final current = store.environmentTier;
          return SettingsScrollView(
            children: [
              SettingsGroup(
                bottomInset: 0,
                children: [
                  for (final tier in kCloudEnvironmentTiers)
                    SettingsOptionTile(
                      title: _label(l10n, tier),
                      selected: current == tier,
                      onTap: () {
                        unawaited(store.setEnvironmentTier(tier));
                      },
                    ),
                ],
              ),
              SettingsHelpFooter(l10n.cloudEnvironmentFooter),
            ],
          );
        },
      ),
    );
  }
}
