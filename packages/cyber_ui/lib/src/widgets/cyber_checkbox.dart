import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';

/// Frost-styled checkbox with click-sound hook.
///
/// Checked fill matches lws-ui `frost_control_checkbox_fill` / `switch_open`
/// (`#34C759`) — standard green, not primary orange.
///
/// [size] scales the Material [Checkbox] face (default [Checkbox.width] = 18).
class CyberCheckbox extends StatelessWidget {
  const CyberCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.clickSoundEnabled = true,
    this.size = Checkbox.width,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final bool clickSoundEnabled;

  /// Painted square edge length (logical px). Default matches Material 18.
  final double size;

  static const _checkedFill = Color(0xFF34C759);

  @override
  Widget build(BuildContext context) {
    void handleChanged(bool? v) {
      if (clickSoundEnabled) {
        CyberClickSoundRegistry.playClick();
      }
      onChanged!(v);
    }

    final scaled = (size - Checkbox.width).abs() >= 0.01;
    final checkbox = Checkbox(
      value: value,
      activeColor: _checkedFill,
      checkColor: Colors.white,
      materialTapTargetSize:
          scaled ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: scaled
          ? const VisualDensity(horizontal: -4, vertical: -4)
          : null,
      onChanged: onChanged == null ? null : handleChanged,
    );
    if (!scaled) {
      return checkbox;
    }
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: Checkbox.width,
          height: Checkbox.width,
          child: checkbox,
        ),
      ),
    );
  }
}
