import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';
import 'package:cyber_ui/src/widgets/cyber_slider.dart';

/// Capsule-chrome slider (simplified Frost capsule stand-in).
class CyberCapsuleSlider extends StatelessWidget {
  const CyberCapsuleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.enabled = true,
    this.label,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final bool enabled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CyberColors.fillMid,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: CyberColors.borderHighlight,
          width: CyberDimens.borderWidth,
        ),
      ),
      child: Row(
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(color: CyberColors.textSecondary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: CyberSlider(
              value: value,
              min: min,
              max: max,
              enabled: enabled,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
