import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';

/// Core progress slider (presentation only).
class CyberSlider extends StatelessWidget {
  const CyberSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.enabled = true,
    this.divisions,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final bool enabled;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: CyberColors.buttonPrimaryAccent,
        thumbColor: CyberColors.textPrimary,
        inactiveTrackColor: CyberColors.borderMid,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: enabled ? onChanged : null,
        onChangeEnd: enabled ? onChangeEnd : null,
      ),
    );
  }
}
