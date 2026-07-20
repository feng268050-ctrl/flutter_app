import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class VolumeSettingsPage extends StatefulWidget {
  const VolumeSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<VolumeSettingsPage> createState() => _VolumeSettingsPageState();
}

class _VolumeSettingsPageState extends State<VolumeSettingsPage> {
  double _volume = 80;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final v = await widget.services.audio.getVolumePercent();
        if (mounted) setState(() => _volume = v.toDouble());
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Volume',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Media Volume'),
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('${_volume.round()}%'),
              ),
              Slider(
                value: _volume.clamp(0, 100),
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _volume = v),
                onChangeEnd: (v) {
                  unawaited(
                    widget.services.audio.setVolumePercent(v.round()),
                  );
                },
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  widget.services.audio.isPlaying
                      ? 'Stop Test Tone'
                      : 'Play Test Tone',
                ),
                trailing: const Icon(Icons.play_arrow),
                onTap: () async {
                  final audio = widget.services.audio;
                  if (audio.isPlaying) {
                    await audio.stop();
                  } else {
                    await audio.playAsset(
                      MediaAudioController.shanghaiTanAsset,
                    );
                  }
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
