import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_slider.dart';
import 'package:cyber_ui/src/widgets/cyber_slider_logic.dart';

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
    this.showDragValueLabel = false,
  });

  final int progress;
  final ValueChanged<int> onProgressChange;
  final ValueChanged<int>? onChangeEnd;
  final int min;
  final int max;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;
  final bool showDragValueLabel;

  static double get _trackHeight =>
      CyberSliderLogic.touchHeight + CyberSliderLogic.thumbDragOverflow * 2;

  @override
  Widget build(BuildContext context) {
    Widget? iconSlot(Widget? icon) {
      if (icon == null) return null;
      return SizedBox(
        height: _trackHeight,
        width: 28,
        child: Center(child: icon),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          iconSlot(leading)!,
          const SizedBox(width: 8),
        ],
        Expanded(
          child: CyberSlider(
            value: progress.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            // No divisions — Material tick marks look like black dots on HMI.
            enabled: enabled,
            showDragValueLabel: showDragValueLabel,
            onChanged: (v) => onProgressChange(v.round()),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(v.round()),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          iconSlot(trailing)!,
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
    this.showDragValueLabel = false,
  });

  final int percent;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onChangeEnd;
  final bool enabled;
  final bool showDragValueLabel;

  @override
  Widget build(BuildContext context) {
    final color = CyberColors.textPrimary.withOpacity(0.85);
    return CyberIconFlankedSlider(
      progress: percent,
      onProgressChange: onChanged,
      onChangeEnd: onChangeEnd,
      enabled: enabled,
      showDragValueLabel: showDragValueLabel,
      leading: Icon(Icons.volume_mute, color: color, size: 22),
      trailing: Icon(Icons.volume_up, color: color, size: 22),
    );
  }
}
