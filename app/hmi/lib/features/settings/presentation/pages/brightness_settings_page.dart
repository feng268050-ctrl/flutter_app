import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

class BrightnessSettingsPage extends StatefulWidget {
  const BrightnessSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<BrightnessSettingsPage> createState() => _BrightnessSettingsPageState();
}

class _BrightnessSettingsPageState extends State<BrightnessSettingsPage> {
  double _brightness = 80;
  bool _busy = false;
  int? _queued;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final v = await widget.services.backlight.getBrightnessPercent();
        if (mounted) setState(() => _brightness = v.toDouble());
      } catch (_) {}
    });
  }

  Future<void> _drain() async {
    if (_busy) return;
    final next = _queued;
    if (next == null) return;
    _queued = null;
    _busy = true;
    try {
      await widget.services.backlight.setBrightnessPercent(next);
    } catch (_) {
    } finally {
      _busy = false;
      if (_queued != null) unawaited(_drain());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.screenBrightnessText,
      body: SettingsScrollView(
        children: [
          SettingsSectionHeader(l10n.screenBrightnessText),
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('${_brightness.round()}%'),
              ),
              Slider(
                value: _brightness.clamp(0, 100),
                min: 0,
                max: 100,
                onChanged: (v) => setState(() => _brightness = v),
                onChangeEnd: (v) {
                  _queued = v.round();
                  unawaited(_drain());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}
