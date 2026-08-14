import 'dart:async';

import 'package:cyber_hal/input.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:os_settings/app/os_settings_app.dart';
import 'package:os_settings/chrome/settings_chrome.dart';
import 'package:os_settings/l10n/app_localizations.dart';

/// Mouse — enable policy + natural scroll, tracking speed, pointer size.
class MousePage extends StatefulWidget {
  const MousePage({super.key});

  @override
  State<MousePage> createState() => _MousePageState();
}

class _MousePageState extends State<MousePage> {
  MouseSettings _settings = MouseSettings.defaults();
  bool _busy = false;
  bool _physicalEnabled = true;
  String? _error;

  PhysicalInputPolicy get _inputPolicy =>
      OsSettingsScope.of(context).physicalInputPolicy();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    final services = OsSettingsScope.of(context);
    try {
      final flags = await services.physicalInputPolicy().readFlags();
      final s = await services.mouse().getSettings();
      if (mounted) {
        setState(() {
          _physicalEnabled = flags.mouseEnabled;
          _settings = s;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _setPhysicalEnabled(bool enabled) async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final flags = await _inputPolicy.readFlags();
      await _inputPolicy.applyFlags(
        flags.copyWith(mouseEnabled: enabled),
      );
      if (!mounted) return;
      await OsSettingsScope.of(context).keyboard().restartToApply();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _physicalEnabled = enabled;
        });
      }
    }
  }

  Future<void> _apply(MouseSettings next) async {
    if (!_physicalEnabled) {
      return;
    }
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
    final l10n = AppLocalizations.of(context)!;
    final prefsEnabled = _physicalEnabled && !_busy;
    return SettingsScaffold(
      title: l10n.mouseText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: _physicalEnabled ? SettingsDimens.inset : 0,
            children: [
              SettingsSwitchRow(
                title: l10n.physicalMouseEnableLabel,
                value: _physicalEnabled,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(_setPhysicalEnabled(v)),
              ),
            ],
          ),
          if (!_physicalEnabled)
            SettingsHelpFooter(l10n.physicalMousePolicyOffHelp),
          if (_physicalEnabled) ...[
            SettingsGroup(
              bottomInset: 0,
              children: [
                SettingsSwitchRow(
                  title: 'Natural Scrolling',
                  value: _settings.naturalScroll,
                  onChanged: prefsEnabled
                      ? (v) => unawaited(
                            _apply(_settings.copyWith(naturalScroll: v)),
                          )
                      : null,
                ),
                SettingsSliderRow(
                  title: 'Tracking Speed',
                  child: CyberSlider(
                    value:
                        _settings.pointerSpeedPercent.toDouble().clamp(0, 100),
                    min: 0,
                    max: 100,
                    enabled: prefsEnabled,
                    showDragValueLabel: true,
                    onChanged: (v) {
                      if (!prefsEnabled) return;
                      setState(
                        () => _settings = _settings.copyWith(
                          pointerSpeedPercent: v.round(),
                        ),
                      );
                    },
                    onChangeEnd: (v) {
                      if (!prefsEnabled) return;
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
                SettingsSliderRow(
                  title: 'Pointer Size',
                  child: CyberSlider(
                    value:
                        _settings.pointerSizePercent.toDouble().clamp(0, 100),
                    min: 0,
                    max: 100,
                    enabled: prefsEnabled,
                    showDragValueLabel: true,
                    onChanged: (v) {
                      if (!prefsEnabled) return;
                      setState(
                        () => _settings = _settings.copyWith(
                          pointerSizePercent: v.round(),
                        ),
                      );
                    },
                    onChangeEnd: (v) {
                      if (!prefsEnabled) return;
                      unawaited(
                        _apply(
                          _settings.copyWith(
                            pointerSizePercent: v.round(),
                          ),
                        ),
                      );
                    },
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
                    onSelectionChanged: prefsEnabled
                        ? (set) {
                            if (set.isEmpty) return;
                            unawaited(
                              _apply(
                                _settings.copyWith(primaryButton: set.first),
                              ),
                            );
                          }
                        : (_) {},
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
        ],
      ),
    );
  }
}
