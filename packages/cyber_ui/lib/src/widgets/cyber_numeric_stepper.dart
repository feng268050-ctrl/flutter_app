import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_button.dart';

/// Numeric stepper (− / value / +).
class CyberNumericStepper extends StatelessWidget {
  const CyberNumericStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.clickSoundEnabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final bool clickSoundEnabled;

  void _bump(int delta) {
    final next = (value + delta).clamp(min, max);
    if (next == value) return;
    if (clickSoundEnabled) {
      CyberClickSoundRegistry.playClick();
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          child: CyberButton(
            size: CyberButtonSize.small,
            variant: CyberButtonVariant.secondary,
            clickSoundEnabled: false,
            onPressed: value <= min ? null : () => _bump(-step),
            child: const Text('−'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$value',
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: CyberButton(
            size: CyberButtonSize.small,
            variant: CyberButtonVariant.secondary,
            clickSoundEnabled: false,
            onPressed: value >= max ? null : () => _bump(step),
            child: const Text('+'),
          ),
        ),
      ],
    );
  }
}
