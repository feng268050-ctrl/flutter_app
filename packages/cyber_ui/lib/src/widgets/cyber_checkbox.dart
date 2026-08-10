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
///
/// When [label] is set, taps on the label (and the gap) also toggle — same hit
/// model as a checkbox + caption row.
class CyberCheckbox extends StatelessWidget {
  const CyberCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.clickSoundEnabled = true,
    this.size = CyberDimens.checkboxSmallSize,
    this.label,
    this.labelGap = 12,
    this.expandLabel = false,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final bool clickSoundEnabled;

  /// Painted square edge length (logical px). Prefer
  /// [CyberDimens.checkboxSmallSize] / [CyberDimens.checkboxLargeSize].
  final double size;

  /// Optional caption; included in the toggle hit target when non-null.
  final Widget? label;

  /// Space between the face and [label].
  final double labelGap;

  /// When true, wraps [label] in [Expanded] (parent must be a [Flex] with
  /// bounded width — e.g. a full-width [Row]).
  final bool expandLabel;

  static const _checkedFill = Color(0xFF34C759);

  /// Material [Checkbox] intrinsic face before scaling.
  static const _materialFace = Checkbox.width;

  void _toggle() {
    final cb = onChanged;
    if (cb == null) {
      return;
    }
    if (clickSoundEnabled) {
      CyberClickSoundRegistry.playClick();
    }
    cb(!value);
  }

  Widget _buildFace() {
    void handleChanged(bool? v) {
      if (clickSoundEnabled) {
        CyberClickSoundRegistry.playClick();
      }
      onChanged!(v);
    }

    final scaled = (size - _materialFace).abs() >= 0.01;
    // When [label] owns the row tap, keep a non-null [onChanged] so the face
    // stays enabled-looking, but swallow pointer via [IgnorePointer].
    final ValueChanged<bool?>? faceChanged = onChanged == null
        ? null
        : (label != null ? (_) {} : handleChanged);
    final checkbox = Checkbox(
      value: value,
      activeColor: _checkedFill,
      checkColor: Colors.white,
      materialTapTargetSize:
          scaled ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: scaled
          ? const VisualDensity(horizontal: -4, vertical: -4)
          : null,
      onChanged: faceChanged,
    );
    final face = !scaled
        ? SizedBox(width: size, height: size, child: checkbox)
        : SizedBox(
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
    if (label == null) {
      return face;
    }
    return IgnorePointer(child: face);
  }

  @override
  Widget build(BuildContext context) {
    final face = _buildFace();
    final caption = label;
    if (caption == null) {
      return face;
    }
    final labelChild = expandLabel ? Expanded(child: caption) : caption;
    return GestureDetector(
      onTap: onChanged == null ? null : _toggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: expandLabel ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          face,
          SizedBox(width: labelGap),
          labelChild,
        ],
      ),
    );
  }
}
