import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// RGB LED test under Display & Sound (moved from Demo).
///
/// While this page is open, production [RgbLedPolicyDriver] is suppressed so
/// manual Steady/Blink/Off is not overwritten by alarm policy.
class LedSettingsPage extends StatefulWidget {
  const LedSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<LedSettingsPage> createState() => _LedSettingsPageState();
}

class _LedSettingsPageState extends State<LedSettingsPage> {
  late final Map<LedColor, IndicatorMode> _modes = {
    for (final c in LedColor.values) c: IndicatorMode.off,
  };

  @override
  void initState() {
    super.initState();
    // Suppress policy first, then force Off so leftover blink/steady is cleared.
    widget.services.rgbLedPolicy?.beginManualOverride();
    unawaited(_resetOnEnter());
  }

  Future<void> _resetOnEnter() async {
    await widget.services.leds.resetAllOff();
    if (!mounted) {
      return;
    }
    setState(() {
      for (final c in LedColor.values) {
        _modes[c] = IndicatorMode.off;
      }
    });
  }

  @override
  void dispose() {
    widget.services.rgbLedPolicy?.endManualOverride();
    super.dispose();
  }

  Future<void> _setMode(LedColor color, IndicatorMode mode) async {
    setState(() => _modes[color] = mode);
    try {
      await widget.services.leds.setMode(color, mode);
    } catch (_) {
      // Soft-fail: UI already reflects the intended mode.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: l10n.rgbLedText,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            bottomInset: 0,
            children: [
              for (final color in LedColor.values)
                SettingsControlRow(
                  title: _colorTitle(color, l10n),
                  control: CyberSegmentedControl<IndicatorMode>(
                    segments: [
                      ButtonSegment(
                        value: IndicatorMode.steadyOn,
                        label: Text(l10n.ledModeSteady),
                      ),
                      ButtonSegment(
                        value: IndicatorMode.blink,
                        label: Text(l10n.ledModeBlink),
                      ),
                      ButtonSegment(
                        value: IndicatorMode.off,
                        label: Text(l10n.offLabel),
                      ),
                    ],
                    selected: {_modes[color]!},
                    onSelectionChanged: (set) {
                      if (set.isEmpty) return;
                      unawaited(_setMode(color, set.first));
                    },
                  ),
                ),
            ],
          ),
          SettingsHelpFooter(l10n.rgbLedFooter),
        ],
      ),
    );
  }

  static String _colorTitle(LedColor color, AppLocalizations l10n) {
    switch (color) {
      case LedColor.red:
        return l10n.ledColorRed;
      case LedColor.yellow:
        return l10n.ledColorYellow;
      case LedColor.green:
        return l10n.ledColorGreen;
    }
  }
}
