import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class UnitSettingsPage extends StatelessWidget {
  const UnitSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CommonSettingsScope.maybeOf(context);
    return SettingsScaffold(
      title: 'Unit',
      body: store == null
          ? const SettingsScrollView(
              children: [
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Unit preference unavailable.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final unit = store.unit;
                return SettingsScrollView(
                  children: [
                    const SettingsSectionHeader('Unit'),
                    SettingsGroup(
                      children: [
                        for (final u in CommonSettingsStore.supportedUnits)
                          SettingsOptionTile(
                            title: u,
                            selected: unit == u,
                            onTap: () {
                              unawaited(store.setUnit(u));
                            },
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Persisted under /var/lib/hmi/common-settings.json.',
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
