import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';

/// Frost-styled switch with click-sound hook.
///
/// On-state track uses the same accent as [CyberSlider] active fill
/// ([CyberColors.buttonPrimaryAccent]); on-thumb is white
/// ([CyberColors.textPrimary]). Off-state keeps Material defaults.
class CyberSwitch extends StatelessWidget {
  const CyberSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.clickSoundEnabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool clickSoundEnabled;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      // Same token as CyberSlider active track — keep project orange unified.
      activeTrackColor: CyberColors.buttonPrimaryAccent,
      // White thumb when on (Slider thumb uses textPrimary).
      activeColor: CyberColors.textPrimary,
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
