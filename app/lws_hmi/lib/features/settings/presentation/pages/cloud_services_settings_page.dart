import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';

/// Cloud services + LAN enhancement toggles (Settings → Network → Cloud services).
class CloudServicesSettingsPage extends StatefulWidget {
  const CloudServicesSettingsPage({
    super.key,
    required this.cloudSettings,
    required this.runtime,
  });

  final CloudSettingsStore cloudSettings;
  final CloudLocalRuntime? runtime;

  @override
  State<CloudServicesSettingsPage> createState() =>
      _CloudServicesSettingsPageState();
}

class _CloudServicesSettingsPageState extends State<CloudServicesSettingsPage> {
  bool _busy = false;

  CloudSettingsStore get _store => widget.cloudSettings;

  Future<void> _setCloud(bool value) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final runtime = widget.runtime;
      if (runtime != null) {
        await runtime.setCloudServicesEnabled(value);
      } else {
        await _store.setCloudServicesEnabled(value);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setLan(bool value) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final runtime = widget.runtime;
      if (runtime != null) {
        await runtime.setLanEnhancementEnabled(value);
      } else {
        await _store.setLanEnhancementEnabled(value);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.cloudServicesText,
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          return SettingsScrollView(
            children: [
              SettingsGroup(
                bottomInset: 0,
                children: [
                  SettingsSwitchRow(
                    title: l10n.cloudServicesText,
                    value: _store.cloudServicesEnabled,
                    onChanged: _busy ? null : (v) => unawaited(_setCloud(v)),
                  ),
                  SettingsSwitchRow(
                    title: l10n.lanEnhancementText,
                    value: _store.lanEnhancementEnabled,
                    onChanged: _busy ? null : (v) => unawaited(_setLan(v)),
                  ),
                ],
              ),
              SettingsHelpFooter(
                l10n.cloudServicesFooter,
                bottomInset: 0,
              ),
              SettingsHelpFooter(l10n.lanEnhancementFooter),
            ],
          );
        },
      ),
    );
  }
}

/// Network-row summary for cloud / LAN enhancement planes.
String cloudServicesNetworkSummary(
  AppLocalizations l10n,
  CloudSettingsStore store,
) {
  store.warmRead();
  final cloud = store.cloudServicesEnabled;
  final lan = store.lanEnhancementEnabled;
  if (cloud && lan) {
    return l10n.cloudServicesSummaryBoth;
  }
  if (cloud) {
    return l10n.cloudServicesSummaryCloud;
  }
  if (lan) {
    return l10n.cloudServicesSummaryLan;
  }
  return l10n.offLabel;
}
