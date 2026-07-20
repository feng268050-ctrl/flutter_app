import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';

/// Frost-styled checkbox with click-sound hook.
class CyberCheckbox extends StatelessWidget {
  const CyberCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.clickSoundEnabled = true,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      activeColor: CyberColors.buttonPrimaryAccent,
      onChanged: onChanged == null
          ? null
          : (v) {
              if (clickSoundEnabled) {
                CyberClickSoundRegistry.playClick();
              }
              onChanged!(v);
            },
    );
  }
}
