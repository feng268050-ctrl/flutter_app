import 'dart:async';

import 'package:cyber_hal/locale.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class UnitSettingsPage extends StatelessWidget {
  const UnitSettingsPage({super.key});

  static String _unitLabel(AppLocalizations l10n, UnitSystem unit) {
    switch (unit) {
      case UnitSystem.imperial:
        return l10n.unitOptionImperial;
      case UnitSystem.metric:
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
                        for (final u in UnitSystem.supported)
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
