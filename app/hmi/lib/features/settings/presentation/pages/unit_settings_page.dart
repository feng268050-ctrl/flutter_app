import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class UnitSettingsPage extends StatefulWidget {
  const UnitSettingsPage({super.key});

  @override
  State<UnitSettingsPage> createState() => _UnitSettingsPageState();
}

class _UnitSettingsPageState extends State<UnitSettingsPage> {
  String _unit = 'Metric';

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Unit',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Unit'),
          SettingsGroup(
            children: [
              for (final u in const ['Metric', 'Imperial'])
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(u),
                  trailing: _unit == u
                      ? const Icon(Icons.check, color: Colors.lightBlueAccent)
                      : null,
                  onTap: () => setState(() => _unit = u),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Unit preference is not persisted yet.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
