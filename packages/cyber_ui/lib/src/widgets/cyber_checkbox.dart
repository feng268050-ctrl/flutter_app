import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';

/// Frost-styled checkbox with click-sound hook.
///
/// Checked fill matches lws-ui `frost_control_checkbox_fill` / `switch_open`
/// (`#34C759`) — standard green, not primary orange.
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

  static const _checkedFill = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      activeColor: _checkedFill,
      checkColor: Colors.white,
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
