import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
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

  MouseSettingAvailability get _avail =>
      widget.services.displayStack.mouseSettings;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await widget.services.ensureDisplayStack();
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
    final avail = _avail;
    final stack = widget.services.displayStack;
    final applyHint = stack.isWeston
        ? 'Applies after a short HMI restart on Weston.'
        : 'Applies live from mouse.conf on flutter-pi.';

    return SettingsScaffold(
      title: 'Mouse',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Mouse'),
          SettingsGroup(
            children: [
              if (avail.naturalScroll)
                SettingsSwitchRow(
                  title: 'Natural Scrolling',
                  value: _settings.naturalScroll,
                  onChanged: _busy
                      ? null
                      : (v) => unawaited(
                            _apply(_settings.copyWith(naturalScroll: v)),
                          ),
                ),
              if (avail.pointerSpeed)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    'Tracking Speed: ${_settings.pointerSpeedPercent}',
                  ),
                  subtitle: Slider(
                    value: _settings.pointerSpeedPercent
                        .toDouble()
                        .clamp(0, 100),
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
              if (avail.scrollSpeed)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    'Scrolling Speed: ${_settings.scrollSpeedPercent}',
                  ),
                  subtitle: Slider(
                    value:
                        _settings.scrollSpeedPercent.toDouble().clamp(0, 100),
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
              if (avail.pointerSize)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    'Pointer Size: ${_settings.pointerSizePercent}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Slider(
                        value: _settings.pointerSizePercent
                            .toDouble()
                            .clamp(0, 100),
                        min: 0,
                        max: 100,
                        onChanged: _busy
                            ? null
                            : (v) => setState(
                                  () => _settings = _settings.copyWith(
                                    pointerSizePercent: v.round(),
                                  ),
                                ),
                        onChangeEnd: _busy
                            ? null
                            : (v) {
                                CyberClickSoundRegistry.playClick();
                                unawaited(
                                  _apply(
                                    _settings.copyWith(
                                      pointerSizePercent: v.round(),
                                    ),
                                  ),
                                );
                              },
                      ),
                      Text(
                        applyHint,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              if (avail.primaryButton)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: const Text('Primary Button'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SegmentedButton<MousePrimaryButton>(
                      segments: const [
                        ButtonSegment(
                          value: MousePrimaryButton.left,
                          label: Text('Left'),
                        ),
                        ButtonSegment(
                          value: MousePrimaryButton.right,
                          label: Text('Right'),
                        ),
                      ],
                      selected: {_settings.primaryButton},
                      onSelectionChanged: _busy
                          ? null
                          : (set) {
                              if (set.isEmpty) {
                                return;
                              }
                              CyberClickSoundRegistry.playClick();
                              unawaited(
                                _apply(
                                  _settings.copyWith(primaryButton: set.first),
                                ),
                              );
                            },
                    ),
                  ),
                ),
              if (avail.pointerAxes)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: const Text('Pointer Axes'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Auto = Raw (native axes). Use Swap XY only if left/right '
                        'moves the pointer up/down.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<MousePointerAxes>(
                        segments: const [
                          ButtonSegment(
                            value: MousePointerAxes.auto,
                            label: Text('Auto'),
                          ),
                          ButtonSegment(
                            value: MousePointerAxes.normal,
                            label: Text('Raw'),
                          ),
                          ButtonSegment(
                            value: MousePointerAxes.swap,
                            label: Text('Swap XY'),
                          ),
                        ],
                        selected: {_settings.pointerAxes},
                        onSelectionChanged: _busy
                            ? null
                            : (set) {
                                if (set.isEmpty) {
                                  return;
                                }
                                CyberClickSoundRegistry.playClick();
                                unawaited(
                                  _apply(
                                    _settings.copyWith(pointerAxes: set.first),
                                  ),
                                );
                              },
                      ),
                    ],
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
