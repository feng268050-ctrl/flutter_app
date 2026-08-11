import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Mouse — natural scroll, tracking speed, pointer size.
class MousePage extends StatefulWidget {
  const MousePage({super.key});

  @override
  State<MousePage> createState() => _MousePageState();
}

class _MousePageState extends State<MousePage> {
  MouseSettings _settings = MouseSettings.defaults();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final s = await OsSettingsScope.of(context).mouse().getSettings();
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
      await OsSettingsScope.of(context).mouse().setSettings(next);
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
          SettingsGroup(
            bottomInset: 0,
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
              SettingsSliderRow(
                title: 'Tracking Speed',
                child: CyberSlider(
                  value:
                      _settings.pointerSpeedPercent.toDouble().clamp(0, 100),
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
                      _settings.copyWith(pointerSpeedPercent: v.round()),
                    ),
                  ),
                ),
              ),
              SettingsSliderRow(
                title: 'Pointer Size',
                child: CyberSlider(
                  value:
                      _settings.pointerSizePercent.toDouble().clamp(0, 100),
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
                      _settings.copyWith(pointerSizePercent: v.round()),
                    ),
                  ),
                ),
              ),
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
          SettingsHelpFooter(
            AppLocalizations.of(context)!.mousePointerHelp,
          ),
        ],
      ),
    );
  }
}
