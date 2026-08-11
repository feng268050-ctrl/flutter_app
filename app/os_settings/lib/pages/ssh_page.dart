import 'dart:async';

import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';

/// SSH — LAN debug toggle.
class SshPage extends StatefulWidget {
  const SshPage({super.key});

  @override
  State<SshPage> createState() => _SshPageState();
}

class _SshPageState extends State<SshPage> {
  bool _enabled = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final on = await OsSettingsScope.of(context).sshDebug().isEnabled();
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
      await OsSettingsScope.of(context).sshDebug().setEnabled(value);
      if (mounted) setState(() => _enabled = value);
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
      title: 'SSH',
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
            children: [
              SettingsSwitchRow(
                title: 'SSH Debug (LAN)',
                value: _enabled,
                onChanged: !_ready ? null : (v) => unawaited(_set(v)),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(SettingsDimens.inset, 12, SettingsDimens.inset, 0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SettingsHelpFooter(
            'When enabled, SSH is reachable on the LAN for engineering debug. '
            'USB SSH is separate and not controlled here.',
          ),
        ],
      ),
    );
  }
}
