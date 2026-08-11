import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Power Mode — performance / balanced (HAL `/var/lib/hal/power.conf`).
///
/// Platform-only; product HMI reads the same store for continuous-paint policy
/// but does not expose a Settings entry.
class PowerModePage extends StatefulWidget {
  const PowerModePage({super.key});

  @override
  State<PowerModePage> createState() => _PowerModePageState();
}

class _PowerModePageState extends State<PowerModePage> {
  LoadProfileMode _mode = LoadProfileMode.performance;
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
      final mode = await OsSettingsScope.of(context).loadProfile().getMode();
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _ready = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _ready = true;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _set(LoadProfileMode mode) async {
    setState(() {
      _mode = mode;
      _error = null;
    });
    try {
      await OsSettingsScope.of(context).loadProfile().setMode(mode);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        await _load();
      }
    }
  }

  String _label(AppLocalizations l10n, LoadProfileMode mode) => switch (mode) {
        LoadProfileMode.performance => l10n.performanceLabel,
        LoadProfileMode.balanced => l10n.balancedLabel,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.powerModeSettingText,
      body: SettingsScrollView(
        children: [
          if (!_ready)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SettingsGroup(
              bottomInset: 0,
              children: [
                for (final m in LoadProfileMode.values)
                  SettingsOptionTile(
                    title: _label(l10n, m),
                    selected: _mode == m,
                    onTap: () => unawaited(_set(m)),
                  ),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                12,
                SettingsDimens.inset,
                0,
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          SettingsHelpFooter(l10n.powerModePersistedFooter),
        ],
      ),
    );
  }
}
