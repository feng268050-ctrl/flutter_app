import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_pill_dropdown.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Display settings — brightness slider + auto screen-off pill dropdown.
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

  List<SettingsPillOption<AutoSleepPolicy>> _screenOffOptions(
    AppLocalizations l10n,
  ) =>
      [
        SettingsPillOption(
          value: AutoSleepPolicy.minutes10,
          label: l10n.screenOffOption10Min,
        ),
        SettingsPillOption(
          value: AutoSleepPolicy.minutes30,
          label: l10n.screenOffOption30Min,
        ),
        SettingsPillOption(
          value: AutoSleepPolicy.minutes60,
          label: l10n.screenOffOption60Min,
        ),
        SettingsPillOption(
          value: AutoSleepPolicy.never,
          label: l10n.screenOffNever,
        ),
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
    await widget.services.autoSleep.setPolicy(policy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = _screenOffOptions(l10n);
    final selectedLabel = options
        .firstWhere(
          (o) => o.value == _screenOff,
          orElse: () => options.last,
        )
        .label;

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
                control: SettingsPillDropdown<AutoSleepPolicy>(
                  value: _screenOff,
                  label: selectedLabel,
                  options: options,
                  enabled: !_loadingScreenOff,
                  onChanged: (v) => unawaited(_setScreenOff(v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
