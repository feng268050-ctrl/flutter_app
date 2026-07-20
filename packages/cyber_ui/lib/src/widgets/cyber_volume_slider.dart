import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_slider.dart';

/// Icon-flanked progress slider (lws-ui `FrostIconFlankedSlider` stand-in).
class CyberIconFlankedSlider extends StatelessWidget {
  const CyberIconFlankedSlider({
    super.key,
    required this.progress,
    required this.onProgressChange,
    this.min = 0,
    this.max = 100,
    this.enabled = true,
    this.leading,
    this.trailing,
    this.onChangeEnd,
  });

  final int progress;
  final ValueChanged<int> onProgressChange;
  final ValueChanged<int>? onChangeEnd;
  final int min;
  final int max;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: CyberSlider(
            value: progress.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max > min ? (max - min) : null,
            enabled: enabled,
            onChanged: (v) => onProgressChange(v.round()),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(v.round()),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// Settings-oriented volume chrome with low/high icons.
class CyberVolumeSlider extends StatelessWidget {
  const CyberVolumeSlider({
    super.key,
    required this.percent,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
  });

  final int percent;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = CyberColors.textPrimary.withOpacity(0.85);
    return CyberIconFlankedSlider(
      progress: percent,
      onProgressChange: onChanged,
      onChangeEnd: onChangeEnd,
      enabled: enabled,
      leading: Icon(Icons.volume_mute, color: color, size: 28),
      trailing: Icon(Icons.volume_up, color: color, size: 28),
    );
  }
}
