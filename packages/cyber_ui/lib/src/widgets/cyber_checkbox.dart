import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';

/// Frost-styled checkbox with click-sound hook.
///
/// Checked fill matches lws-ui `frost_control_checkbox_fill` / `switch_open`
/// (`#34C759`) — standard green, not primary orange.
///
/// Face size uses two tiers via [CyberDimens.checkboxSmallSize] (default) /
/// [CyberDimens.checkboxLargeSize]. Shape stays Material square.
class CyberCheckbox extends StatelessWidget {
  const CyberCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.clickSoundEnabled = true,
    this.size = CyberDimens.checkboxSmallSize,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final bool clickSoundEnabled;

  /// Painted square edge length (logical px). Prefer
  /// [CyberDimens.checkboxSmallSize] / [CyberDimens.checkboxLargeSize].
  final double size;

  static const _checkedFill = Color(0xFF34C759);

  /// Material [Checkbox] intrinsic face before scaling.
  static const _materialFace = Checkbox.width;

  @override
  Widget build(BuildContext context) {
    void handleChanged(bool? v) {
      if (clickSoundEnabled) {
        CyberClickSoundRegistry.playClick();
      }
      onChanged!(v);
    }

    final scaled = (size - _materialFace).abs() >= 0.01;
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
      return SizedBox(
        width: size,
        height: size,
        child: checkbox,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _materialFace,
          height: _materialFace,
          child: checkbox,
        ),
      ),
    );
  }
}
