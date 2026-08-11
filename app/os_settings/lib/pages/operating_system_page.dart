import 'dart:async';

import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';
import 'package:os_settings/util/os_settings_labels.dart';
import 'package:os_settings/util/platform_versions.dart';

/// Operating System — grouped version inventory (soft-fail → —).
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final services = OsSettingsScope.of(context);
      final seal = services.secretsSealStatus();
      final versions = await services.platformVersions().snapshot();
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
              SettingsGroup(
                bottomInset: sections[i].titleKey == 'osSecuritySection'
                    ? 0
                    : (i == sections.length - 1
                        ? 0
                        : SettingsDimens.groupGap),
                children: [
                  for (final row in sections[i].rows)
                    SettingsValueRow(
                      title: platformVersionLabel(l10n, row.$1),
                      value: dashOr(row.$2(snap)),
                    ),
                  if (sections[i].titleKey == 'osSecuritySection')
                    SettingsValueRow(
                      title: l10n.secretsSealText,
                      value: _seal,
                    ),
                ],
              ),
              if (sections[i].titleKey == 'osSecuritySection')
                SettingsHelpFooter(l10n.secretsSealHelp),
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
