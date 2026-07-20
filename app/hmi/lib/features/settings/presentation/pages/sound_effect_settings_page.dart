import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class SoundEffectSettingsPage extends StatefulWidget {
  const SoundEffectSettingsPage({super.key});

  @override
  State<SoundEffectSettingsPage> createState() =>
      _SoundEffectSettingsPageState();
}

class _SoundEffectSettingsPageState extends State<SoundEffectSettingsPage> {
  String _value = 'Default';

  @override
  Widget build(BuildContext context) {
    const options = ['Default', 'Soft', 'Off'];
    return SettingsScaffold(
      title: 'Sound Effect',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Click Sound'),
          SettingsGroup(
            children: [
              for (final o in options)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(o),
                  trailing: _value == o
                      ? const Icon(Icons.check, color: Colors.lightBlueAccent)
                      : null,
                  onTap: () => setState(() => _value = o),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Sound-effect preference is not persisted yet.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
