import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

class MouseSettingsPage extends StatefulWidget {
  const MouseSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<MouseSettingsPage> createState() => _MouseSettingsPageState();
}

class _MouseSettingsPageState extends State<MouseSettingsPage> {
  MouseSettings _settings = MouseSettings.defaults();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final s = await widget.services.mouse.getSettings();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _apply(MouseSettings next) async {
    setState(() {
      _busy = true;
      _error = null;
      _settings = next;
    });
    try {
      await widget.services.mouse.setSettings(next);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Mouse',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Mouse'),
          SettingsGroup(
            children: [
              SettingsSwitchRow(
                title: 'Natural Scrolling',
                value: _settings.naturalScroll,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(
                          _apply(_settings.copyWith(naturalScroll: v)),
                        ),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'Tracking Speed: ${_settings.pointerSpeedPercent}',
                ),
                subtitle: Slider(
                  value:
                      _settings.pointerSpeedPercent.toDouble().clamp(0, 100),
                  min: 0,
                  max: 100,
                  onChanged: _busy
                      ? null
                      : (v) => setState(
                            () => _settings = _settings.copyWith(
                              pointerSpeedPercent: v.round(),
                            ),
                          ),
                  onChangeEnd: _busy
                      ? null
                      : (v) {
                          CyberClickSoundRegistry.playClick();
                          unawaited(
                            _apply(
                              _settings.copyWith(
                                pointerSpeedPercent: v.round(),
                              ),
                            ),
                          );
                        },
                ),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'Scrolling Speed: ${_settings.scrollSpeedPercent}',
                ),
                subtitle: Slider(
                  value: _settings.scrollSpeedPercent.toDouble().clamp(0, 100),
                  min: 0,
                  max: 100,
                  onChanged: _busy
                      ? null
                      : (v) => setState(
                            () => _settings = _settings.copyWith(
                              scrollSpeedPercent: v.round(),
                            ),
                          ),
                  onChangeEnd: _busy
                      ? null
                      : (v) {
                          CyberClickSoundRegistry.playClick();
                          unawaited(
                            _apply(
                              _settings.copyWith(
                                scrollSpeedPercent: v.round(),
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }
}
