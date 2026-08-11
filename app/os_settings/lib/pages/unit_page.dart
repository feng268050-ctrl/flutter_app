import 'dart:async';

import 'package:cyber_hal/locale.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Unit — Metric / Imperial in locale.conf.
class UnitPage extends StatefulWidget {
  const UnitPage({super.key});

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
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

  String _label(UnitSystem unit) => switch (unit) {
        UnitSystem.metric => 'Metric',
        UnitSystem.imperial => 'Imperial',
      };

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    return SettingsScaffold(
      title: 'Unit',
      body: !_ready || locale == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: locale,
              builder: (context, _) {
                final unit = locale.unit;
                return SettingsScrollView(
                  children: [
                    SettingsGroup(
                      bottomInset: 0,
                      children: [
                        for (final u in UnitSystem.supported)
                          SettingsOptionTile(
                            title: _label(u),
                            selected: unit == u,
                            onTap: () {
                              unawaited(locale.setUnit(u));
                            },
                          ),
                      ],
                    ),
                    SettingsHelpFooter(
                      AppLocalizations.of(context)!.unitSettingHelp,
                    ),
                  ],
                );
              },
            ),
    );
  }
}
