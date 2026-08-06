import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class UnitSettingsPage extends StatelessWidget {
  const UnitSettingsPage({super.key});

  static String _unitLabel(AppLocalizations l10n, String unit) {
    switch (unit) {
      case CommonSettingsStore.unitImperial:
        // lws-ui `unit_option_imperial`
        return l10n.unitOptionImperial;
      case CommonSettingsStore.unitMetric:
      default:
        // lws-ui `unit_option_metric`
        return l10n.unitOptionMetric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final store = CommonSettingsScope.maybeOf(context);
    return SettingsScaffold(
      title: l10n.unitSettingText,
      body: store == null
          ? SettingsScrollView(
              children: [
                SettingsHelpFooter(l10n.unitPreferenceUnavailable),
              ],
            )
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final unit = store.unit;
                return SettingsScrollView(
                  children: [
                    SettingsGroup(
                      bottomInset: 0,
                      children: [
                        for (final u in CommonSettingsStore.supportedUnits)
                          SettingsOptionTile(
                            title: _unitLabel(l10n, u),
                            selected: unit == u,
                            onTap: () {
                              unawaited(store.setUnit(u));
                            },
                          ),
                      ],
                    ),
                    SettingsHelpFooter(l10n.unitPersistedFooter),
                  ],
                );
              },
            ),
    );
  }
}
