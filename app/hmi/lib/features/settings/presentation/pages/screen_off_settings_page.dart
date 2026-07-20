import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class ScreenOffSettingsPage extends StatefulWidget {
  const ScreenOffSettingsPage({super.key});

  @override
  State<ScreenOffSettingsPage> createState() => _ScreenOffSettingsPageState();
}

class _ScreenOffSettingsPageState extends State<ScreenOffSettingsPage> {
  String _value = 'Never';

  @override
  Widget build(BuildContext context) {
    const options = ['10 min', '30 min', '60 min', 'Never'];
    return SettingsScaffold(
      title: 'Screen-off Time',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Auto-Lock'),
          SettingsGroup(
            children: [
              for (final o in options)
                SettingsOptionTile(
                  title: o,
                  selected: _value == o,
                  onTap: () => setState(() => _value = o),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Screen-off preference is not persisted yet.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
