import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.sshDebugText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
            children: [
              SettingsSwitchRow(
                title: l10n.sshDebugText,
                value: _enabled,
                onChanged: !_ready ? null : (v) => unawaited(_set(v)),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                SettingsDimens.helpGap,
                SettingsDimens.inset,
                0,
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: AppTypography.captionSize),
              ),
            ),
          SettingsHelpFooter(l10n.sshDebugFooter),
        ],
      ),
    );
  }
}
