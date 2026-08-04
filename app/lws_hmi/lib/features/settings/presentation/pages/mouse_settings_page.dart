import 'dart:async';

import 'package:cyber_hal/input.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return SettingsScaffold(
      title: l10n.mouseText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
            children: [
              SettingsSwitchRow(
                title: l10n.mouseNaturalScrolling,
                value: _settings.naturalScroll,
                onChanged: _busy
                    ? null
                    : (v) => unawaited(
                          _apply(_settings.copyWith(naturalScroll: v)),
                        ),
              ),
              SettingsSliderRow(
                title: l10n.mouseTrackingSpeed,
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
                      _settings.copyWith(
                        pointerSpeedPercent: v.round(),
                      ),
                    ),
                  ),
                ),
              ),
              SettingsSliderRow(
                title: l10n.mousePointerSize,
                child: CyberSlider(
                  value: _settings.pointerSizePercent.toDouble().clamp(0, 100),
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
              SettingsControlRow(
                title: l10n.mousePrimaryButton,
                control: CyberSegmentedControl<MousePrimaryButton>(
                  segments: [
                    ButtonSegment(
                      value: MousePrimaryButton.left,
                      label: Text(l10n.mouseButtonLeft),
                    ),
                    ButtonSegment(
                      value: MousePrimaryButton.right,
                      label: Text(l10n.mouseButtonRight),
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
          SettingsHelpFooter(l10n.settingsMayRestartApp),
        ],
      ),
    );
  }
}
