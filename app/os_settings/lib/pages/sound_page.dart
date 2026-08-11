import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Sound — system volume only (click samples are installed by product HMI).
class SoundPage extends StatefulWidget {
  const SoundPage({super.key});

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> {
  int _volume = 80;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final v = await OsSettingsScope.of(context).mediaAudio().getVolumePercent();
      if (mounted) setState(() => _volume = v);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.soundSettings,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
            children: [
              SettingsSliderRow(
                title: l10n.volumeText,
                child: CyberVolumeSlider(
                  percent: _volume.clamp(0, 100),
                  showDragValueLabel: true,
                  onChanged: (v) => setState(() => _volume = v),
                  onChangeEnd: (v) {
                    unawaited(
                      OsSettingsScope.of(context)
                          .mediaAudio()
                          .setVolumePercent(v),
                    );
                  },
                ),
              ),
            ],
          ),
          SettingsHelpFooter(l10n.volumeOnlyHelp),
        ],
      ),
    );
  }
}
