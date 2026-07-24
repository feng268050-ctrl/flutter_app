import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

/// SSH debug toggle over LAN (Settings → Network, after HTTP Proxy).
class LanSshDebugSettingsPage extends StatefulWidget {
  const LanSshDebugSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<LanSshDebugSettingsPage> createState() =>
      _LanSshDebugSettingsPageState();
}

class _LanSshDebugSettingsPageState extends State<LanSshDebugSettingsPage> {
  bool _enabled = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final on = await widget.services.sshDebug.isEnabled();
      if (mounted) {
        setState(() {
          _enabled = on;
          _ready = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _enabled = false;
          _ready = true;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _set(bool value) async {
    setState(() => _error = null);
    try {
      await widget.services.sshDebug.setEnabled(value);
      if (mounted) {
        setState(() => _enabled = value);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'SSH Debug',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('SSH'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'SSH Debug over LAN',
                value: _enabled,
                onChanged: !_ready ? null : (v) => unawaited(_set(v)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Enables on-demand OpenSSH on eth0/wlan0. Not persisted across reboot. '
            'USB plug-ssh uses OTG mode Debug over USB separately.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
