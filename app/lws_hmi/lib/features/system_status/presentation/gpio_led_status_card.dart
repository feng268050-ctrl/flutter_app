import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

/// Large R/Y/G lamps only (no labels) for the emulator GPIO LED overlay.
///
/// On mount: [GpioLedController.ensureWatching] (one [GpioLine.get] each).
/// Afterwards: lit state follows HAL [GpioLevelListener] on every [GpioLine.set].
class GpioLedStatusCard extends StatefulWidget {
  const GpioLedStatusCard({super.key});

  static const double lampSize = 36;

  @override
  State<GpioLedStatusCard> createState() => _GpioLedStatusCardState();
}

class _GpioLedStatusCardState extends State<GpioLedStatusCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final services = AppScope.maybeOf(context);
      if (services == null || !mounted) {
        return;
      }
      // ignore: discarded_futures
      services.leds.ensureWatching();
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: services.leds,
      builder: (context, _) {
        final leds = services.leds;
        return IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in LedColor.values) ...[
                if (color != LedColor.values.first) const SizedBox(height: 14),
                _LedLamp(color: color, lit: leds.isOn(color)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LedLamp extends StatelessWidget {
  const _LedLamp({required this.color, required this.lit});

  final LedColor color;
  final bool lit;

  Color get _base {
    switch (color) {
      case LedColor.red:
        return const Color(0xFFE53935);
      case LedColor.yellow:
        return const Color(0xFFFDD835);
      case LedColor.green:
        return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _base;
    return Container(
      width: GpioLedStatusCard.lampSize,
      height: GpioLedStatusCard.lampSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? color : color.withOpacity(0.18),
        border: Border.all(
          color: lit ? Colors.white54 : Colors.white24,
          width: 1.5,
        ),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: color.withOpacity(0.75),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
