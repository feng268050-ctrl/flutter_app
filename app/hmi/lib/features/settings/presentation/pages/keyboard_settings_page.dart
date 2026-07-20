import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/ui/demo/keyboard_demo_section.dart';

/// Keyboard settings page — layout / HID smoke in Settings chrome.
class KeyboardSettingsPage extends StatelessWidget {
  const KeyboardSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Keyboard',
      body: SettingsScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          const SettingsSectionHeader('Keyboard'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: KeyboardDemoSection(keyboard: services.keyboard),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
