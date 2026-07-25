import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final avail = _avail;

    return SettingsScaffold(
      title: l10n.mouseText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
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
                SettingsSliderRow(
                  title: 'Tracking Speed',
                  child: CyberSlider(
                    value: _settings.pointerSpeedPercent
                        .toDouble()
                        .clamp(0, 100),
                    min: 0,
                    max: 100,
                    enabled: !_busy,
                    showDragValueLabel: true,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(
                        pointerSpeedPercent: v.round(),
                      ),
                    ),
                    onChangeEnd: (v) => unawaited(
                      _apply(
                        _settings.copyWith(
                          pointerSpeedPercent: v.round(),
                        ),
                      ),
                    ),
                  ),
                ),
              if (avail.scrollSpeed)
                SettingsSliderRow(
                  title: 'Scrolling Speed',
                  child: CyberSlider(
                    value: _settings.scrollSpeedPercent
                        .toDouble()
                        .clamp(0, 100),
                    min: 0,
                    max: 100,
                    enabled: !_busy,
                    showDragValueLabel: true,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(
                        scrollSpeedPercent: v.round(),
                      ),
                    ),
                    onChangeEnd: (v) => unawaited(
                      _apply(
                        _settings.copyWith(
                          scrollSpeedPercent: v.round(),
                        ),
                      ),
                    ),
                  ),
                ),
              if (avail.pointerSize)
                SettingsSliderRow(
                  title: 'Pointer Size',
                  child: CyberSlider(
                    value: _settings.pointerSizePercent
                        .toDouble()
                        .clamp(0, 100),
                    min: 0,
                    max: 100,
                    enabled: !_busy,
                    showDragValueLabel: true,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(
                        pointerSizePercent: v.round(),
                      ),
                    ),
                    onChangeEnd: (v) => unawaited(
                      _apply(
                        _settings.copyWith(
                          pointerSizePercent: v.round(),
                        ),
                      ),
                    ),
                  ),
                ),
              if (avail.primaryButton)
                SettingsControlRow(
                  title: 'Primary Button',
                  control: CyberSegmentedControl<MousePrimaryButton>(
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
                        ? (_) {}
                        : (set) {
                            if (set.isEmpty) return;
                            unawaited(
                              _apply(
                                _settings.copyWith(primaryButton: set.first),
                              ),
                            );
                          },
                  ),
                ),
              if (avail.pointerAxes)
                SettingsControlRow(
                  title: 'Pointer Axes',
                  subtitle:
                      'Auto = Raw (native axes). Use Swap XY only if left/right '
                      'moves the pointer up/down.',
                  control: CyberSegmentedControl<MousePointerAxes>(
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
                        ? (_) {}
                        : (set) {
                            if (set.isEmpty) return;
                            unawaited(
                              _apply(
                                _settings.copyWith(pointerAxes: set.first),
                              ),
                            );
                          },
                  ),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SettingsDimens.inset,
                SettingsDimens.helpGap,
                SettingsDimens.inset,
                0,
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          SettingsHelpFooter(l10n.settingsMayRestartApp),
        ],
      ),
    );
  }
}
