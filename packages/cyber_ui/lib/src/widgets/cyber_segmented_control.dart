import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';

/// Segmented selection control (Settings-ready).
class CyberSegmentedControl<T> extends StatelessWidget {
  const CyberSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.clickSoundEnabled = true,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CyberColors.fillSolidTop;
          }
          return CyberColors.textPrimary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CyberColors.textPrimary;
          }
          return CyberColors.fillMid;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: CyberColors.borderHighlight,
            width: CyberDimens.borderWidth,
          ),
        ),
      ),
      onSelectionChanged: (next) {
        if (clickSoundEnabled) {
          CyberClickSoundRegistry.playClick();
        }
        onSelectionChanged(next);
      },
    );
  }
}
