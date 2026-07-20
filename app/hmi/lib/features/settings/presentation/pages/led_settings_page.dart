import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/gpio/gpio_led_config.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

/// RGB LED debug under Display & Sound (moved from Demo).
class LedSettingsPage extends StatefulWidget {
  const LedSettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<LedSettingsPage> createState() => _LedSettingsPageState();
}

class _LedSettingsPageState extends State<LedSettingsPage> {
  final Map<LedColor, IndicatorMode> _modes = {
    for (final c in LedColor.values) c: IndicatorMode.off,
  };
  String _pinCaption = 'Pins R/Y/G (loading gpio.json…)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadCaption());
    });
  }

  Future<void> _loadCaption() async {
    try {
      final cfg = await widget.services.leds.config;
      if (mounted) {
        setState(() => _pinCaption = gpioLedPinCaption(cfg));
      }
    } catch (_) {
      // Keep placeholder when gpio.json missing.
    }
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
    return SettingsScaffold(
      title: 'RGB LED',
      body: SettingsScrollView(
        children: [
          const SettingsSectionHeader('Indicator LEDs'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _pinCaption,
              style: TextStyle(color: Colors.white.withOpacity(0.55)),
            ),
          ),
          for (final color in LedColor.values) ...[
            SettingsGroup(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(_colorTitle(color)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SegmentedButton<IndicatorMode>(
                      segments: const [
                        ButtonSegment(
                          value: IndicatorMode.steadyOn,
                          label: Text('Steady'),
                        ),
                        ButtonSegment(
                          value: IndicatorMode.blink,
                          label: Text('Blink'),
                        ),
                        ButtonSegment(
                          value: IndicatorMode.off,
                          label: Text('Off'),
                        ),
                      ],
                      selected: {_modes[color]!},
                      onSelectionChanged: (set) {
                        if (set.isEmpty) return;
                        unawaited(_setMode(color, set.first));
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  static String _colorTitle(LedColor color) {
    switch (color) {
      case LedColor.red:
        return 'Red';
      case LedColor.yellow:
        return 'Yellow';
      case LedColor.green:
        return 'Green';
    }
  }
}
