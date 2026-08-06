import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_scope.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_pill_dropdown.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Sound settings — volume slider + sound-effect pill dropdown.
class SoundSettingsPage extends StatefulWidget {
  const SoundSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<SoundSettingsPage> createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends State<SoundSettingsPage> {
  int _volume = 80;
  int _effectIndex = SoundEffectStore.defaultIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final v = await widget.services.audio.getVolumePercent();
        if (mounted) setState(() => _volume = v);
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = SoundEffectScope.maybeOf(context);
    if (scope != null) {
      _effectIndex = scope.store.index;
    }
  }

  String _effectLabel(AppLocalizations l10n, int i) => switch (i) {
        1 => l10n.soundEffectOption2,
        2 => l10n.soundEffectOption3,
        _ => l10n.soundEffectOption1,
      };

  Future<void> _setEffect(int index) async {
    final next = SoundEffectStore.clampIndex(index);
    setState(() => _effectIndex = next);
    final scope = SoundEffectScope.maybeOf(context);
    if (scope != null) {
      await scope.clickSound.openEffect(next);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsScaffold(
      title: l10n.soundSettings,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSliderRow(
                title: l10n.volumeSettingText,
                child: CyberVolumeSlider(
                  percent: _volume.clamp(0, 100),
                  showDragValueLabel: true,
                  onChanged: (v) => setState(() => _volume = v),
                  onChangeEnd: (v) {
                    unawaited(widget.services.audio.setVolumePercent(v));
                  },
                ),
              ),
              SettingsControlRow(
                title: l10n.soundEffectCheck,
                control: SettingsPillDropdown<int>(
                  value: _effectIndex,
                  label: _effectLabel(l10n, _effectIndex),
                  options: [
                    for (var i = 0; i < SoundEffectStore.effectCount; i++)
                      SettingsPillOption(
                        value: i,
                        label: _effectLabel(l10n, i),
                      ),
                  ],
                  onChanged: (v) => unawaited(_setEffect(v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
