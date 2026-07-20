import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _lang = 'EN';

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Language',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Language'),
          SettingsGroup(
            children: [
              for (final code in const ['EN', 'ZH'])
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(code == 'EN' ? 'English' : '中文'),
                  trailing: _lang == code
                      ? const Icon(Icons.check, color: Colors.lightBlueAccent)
                      : null,
                  onTap: () => setState(() => _lang = code),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Language preference is not persisted yet.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
