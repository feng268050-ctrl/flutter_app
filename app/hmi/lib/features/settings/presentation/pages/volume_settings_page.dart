import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class VolumeSettingsPage extends StatefulWidget {
  const VolumeSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<VolumeSettingsPage> createState() => _VolumeSettingsPageState();
}

class _VolumeSettingsPageState extends State<VolumeSettingsPage> {
  int _volume = 80;
  bool _playing = false;
  StreamSubscription<bool>? _playingSub;

  MediaAudioController get _audio => widget.services.audio;

  @override
  void initState() {
    super.initState();
    _playing = _audio.isPlaying;
    _playingSub = _audio.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final v = await _audio.getVolumePercent();
        if (mounted) setState(() => _volume = v);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    unawaited(_playingSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_audio.isPlaying || _playing) {
        await _audio.stop();
      } else {
        await _audio.playAsset(MediaAudioController.shanghaiTanAsset);
      }
    } catch (e, st) {
      debugPrint('volume-settings: play/stop failed: $e\n$st');
    }
    if (mounted) setState(() => _playing = _audio.isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.volumeSettingText,
      body: SettingsScrollView(
        children: [
          // Media volume
          SettingsGroup(
            borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('$_volume%'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: CyberVolumeSlider(
                  percent: _volume.clamp(0, 100),
                  onChanged: (v) => setState(() => _volume = v),
                  onChangeEnd: (v) {
                    unawaited(_audio.setVolumePercent(v));
                  },
                ),
              ),
            ],
          ),
          // Play test
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.bottomLeftTopRight,
            children: [
              CyberAudioPlayerCard(
                isPlaying: _playing,
                position: Duration.zero,
                duration: Duration.zero,
                seekEnabled: false,
                clickSoundEnabled: false,
                onPlayPause: () {
                  unawaited(_togglePlay());
                },
                onRewind: _playing
                    ? () {
                        unawaited(_audio.stop().then((_) => _togglePlay()));
                      }
                    : null,
                onFastForward: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
