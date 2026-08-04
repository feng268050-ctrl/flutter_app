import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// Display settings — brightness slider + auto screen-off dropdown.
class DisplaySettingsPage extends StatefulWidget {
  const DisplaySettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  double _brightness = 80;
  AutoSleepPolicy _screenOff = AutoSleepPolicy.never;
  bool _loadingScreenOff = true;
  bool _busyBrightness = false;
  int? _queuedBrightness;

  List<(AutoSleepPolicy, String Function(AppLocalizations l10n))> _screenOffOptions(
    AppLocalizations l10n,
  ) =>
      [
        (AutoSleepPolicy.minutes10, (_) => l10n.screenOffOption10Min),
        (AutoSleepPolicy.minutes30, (_) => l10n.screenOffOption30Min),
        (AutoSleepPolicy.minutes60, (_) => l10n.screenOffOption60Min),
        (AutoSleepPolicy.never, (_) => l10n.screenOffNever),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadBrightness());
      unawaited(_loadScreenOff());
    });
  }

  Future<void> _loadBrightness() async {
    try {
      final v = await widget.services.backlight.getBrightnessPercent();
      if (mounted) setState(() => _brightness = v.toDouble());
    } catch (_) {}
  }

  Future<void> _loadScreenOff() async {
    try {
      final policy = await widget.services.autoSleep.getPolicy();
      if (!mounted) return;
      setState(() {
        _screenOff = policy;
        _loadingScreenOff = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingScreenOff = false);
    }
  }

  Future<void> _drainBrightness() async {
    if (_busyBrightness) return;
    final next = _queuedBrightness;
    if (next == null) return;
    _queuedBrightness = null;
    _busyBrightness = true;
    try {
      await widget.services.backlight.setBrightnessPercent(next);
    } catch (_) {
    } finally {
      _busyBrightness = false;
      if (_queuedBrightness != null) unawaited(_drainBrightness());
    }
  }

  Future<void> _setScreenOff(AutoSleepPolicy policy) async {
    setState(() => _screenOff = policy);
    CyberClickSoundRegistry.playClick();
    await widget.services.autoSleep.setPolicy(policy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = _screenOffOptions(l10n);

    return SettingsScaffold(
      title: l10n.screenSettings,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsSliderRow(
                title: l10n.screenBrightnessText,
                child: CyberSlider(
                  value: _brightness.clamp(0, 100),
                  min: 0,
                  max: 100,
                  showDragValueLabel: true,
                  onChanged: (v) => setState(() => _brightness = v),
                  onChangeEnd: (v) {
                    _queuedBrightness = v.round();
                    unawaited(_drainBrightness());
                  },
                ),
              ),
              SettingsControlRow(
                title: l10n.screenOffTimeText,
                control: DropdownButtonHideUnderline(
                  child: DropdownButton<AutoSleepPolicy>(
                    value: _screenOff,
                    isDense: true,
                    dropdownColor: CyberColors.fillSolidMid,
                    style: context.hmiTypography.body.copyWith(
                      color: CyberColors.textPrimary,
                    ),
                    iconEnabledColor: CyberColors.textSecondary,
                    items: [
                      for (final (policy, label) in options)
                        DropdownMenuItem(
                          value: policy,
                          child: Text(label(l10n)),
                        ),
                    ],
                    onChanged: _loadingScreenOff
                        ? null
                        : (v) {
                            if (v == null) return;
                            unawaited(_setScreenOff(v));
                          },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
