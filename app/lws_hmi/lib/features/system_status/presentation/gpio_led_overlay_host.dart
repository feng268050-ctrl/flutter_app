import 'package:flutter/material.dart';
import 'package:lws_hmi/features/system_status/presentation/gpio_led_status_card.dart';

/// Emulator-only GPIO LED lamps (top-left), clear of [SystemStatusOverlayHost]
/// (center-left). Real boards never enable this host.
///
/// Hit-testing: decorative only ([GpioLedStatusCard] uses [IgnorePointer]).
class GpioLedOverlayHost extends StatelessWidget {
  const GpioLedOverlayHost({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// True on P3.2 sim / QEMU guest (`board_id == sim`).
  final bool enabled;
  final Widget child;

  /// Below CyberUI / work-mode status chrome so lamps sit in the upper-left
  /// content band (clear of the status strip and center-left system overlay).
  static const double topInset = 120;
  static const double leftInset = 16;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: leftInset, top: topInset),
            child: GpioLedStatusCard(),
          ),
        ),
      ],
    );
  }
}
