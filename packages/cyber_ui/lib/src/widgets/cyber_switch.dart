import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';

/// Frost-styled switch with click-sound hook.
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
