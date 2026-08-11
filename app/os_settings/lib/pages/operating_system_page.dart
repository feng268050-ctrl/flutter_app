import 'dart:async';

import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/util/os_settings_labels.dart';
import 'package:os_settings/util/platform_versions.dart';

/// Operating System — grouped version inventory (soft-fail → —).
///
/// Uses the root-shell-warmed [OsSettingsServices.cachedPlatformVersions]
/// when present (pins do not change at runtime); cold path probes once.
///
/// First group (Platform) has no section title. Secrets Seal lives under Security.
class OperatingSystemPage extends StatefulWidget {
  const OperatingSystemPage({super.key});

  @override
  State<OperatingSystemPage> createState() => _OperatingSystemPageState();
}

class _OperatingSystemPageState extends State<OperatingSystemPage> {
  PlatformVersionsSnapshot? _versions;
  String _seal = kUnavailable;
  bool _loading = true;
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    final services = OsSettingsScope.of(context);
    final cached = services.cachedPlatformVersions;
    if (cached != null) {
      _versions = cached;
      _seal = services.secretsSealStatus();
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final services = OsSettingsScope.of(context);
      final seal = services.secretsSealStatus();
      final versions = await services.platformVersionsSnapshot();
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _seal = seal;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _versions = const PlatformVersionsSnapshot();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final snap = _versions ?? const PlatformVersionsSnapshot();
    final sections = platformVersionSections(snap);

    return SettingsScaffold(
      title: l10n.operatingSystemText,
      body: SettingsScrollView(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            for (var i = 0; i < sections.length; i++) ...[
              if (sections[i].titleKey != 'osPlatformSection')
                SettingsSectionHeader(
                  platformVersionSectionTitle(l10n, sections[i].titleKey),
                  topInset:
                      i == 0 ? SettingsDimens.inset : SettingsDimens.groupGap,
                ),
              if (sections[i].titleKey == 'osSecuritySection') ...[
                SettingsGroup(
                  bottomInset: 0,
                  children: [
                    for (final row in sections[i].rows)
                      SettingsValueRow(
                        title: platformVersionLabel(l10n, row.$1),
                        value: dashOr(row.$2(snap)),
                      ),
                    SettingsValueRow(
                      title: l10n.secretsSealText,
                      value: _seal,
                    ),
                  ],
                ),
                SettingsHelpFooter(
                  l10n.selinuxHelp,
                  bottomInset: 0,
                ),
                SettingsHelpFooter(l10n.secretsSealHelp),
              ] else
                SettingsGroup(
                  bottomInset: i == sections.length - 1
                      ? 0
                      : SettingsDimens.groupGap,
                  children: [
                    for (final row in sections[i].rows)
                      SettingsValueRow(
                        title: platformVersionLabel(l10n, row.$1),
                        value: dashOr(row.$2(snap)),
                      ),
                  ],
                ),
              if (sections[i].titleKey == 'osSecuritySection' &&
                  i < sections.length - 1)
                const SizedBox(height: SettingsDimens.groupGap),
            ],
          ],
        ],
      ),
    );
  }
}
