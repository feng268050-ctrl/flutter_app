import 'package:flutter/material.dart';

import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/widgets/cyber_slider.dart';

/// Slider with optional min / max / zero scale labels (lws-ui `FrostSlider`
/// `frostScaleMinText` / `frostScaleMaxText` / center `0`).
class CyberScaledSlider extends StatelessWidget {
  const CyberScaledSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 100,
    this.enabled = true,
    this.divisions,
    this.longPressDragEnabled = true,
    this.scaleMinText,
    this.scaleMaxText,
    this.scaleZeroText = '0',
    this.showZeroLabel,
    this.scaleLabelFontSize = 12,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final bool enabled;
  final int? divisions;

  /// Frost long-press anti-mis-touch (see [CyberSlider.longPressDragEnabled]).
  final bool longPressDragEnabled;
  final String? scaleMinText;
  final String? scaleMaxText;
  final String scaleZeroText;

  /// When null, shows zero when [min] &lt; 0 &lt; [max] (Frost parity).
  final bool? showZeroLabel;

  /// Min / max / zero scale label size (match sibling title when set).
  final double scaleLabelFontSize;

  bool get _showZero =>
      showZeroLabel ?? (min < 0 && max > 0);

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: CyberColors.textSecondary,
      fontSize: scaleLabelFontSize,
      height: 1.1,
    );
    final span = max - min;
    final zeroFraction = span == 0 ? 0.0 : (0 - min) / span;
    final scaleBandHeight = (scaleLabelFontSize * 1.35).clamp(18.0, 36.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberSlider(
          value: value,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
          min: min,
          max: max,
          enabled: enabled,
          divisions: divisions,
          longPressDragEnabled: longPressDragEnabled,
        ),
        if (scaleMinText != null || scaleMaxText != null || _showZero)
          SizedBox(
            height: scaleBandHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (scaleMinText != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(scaleMinText!, style: labelStyle),
                      ),
                    if (scaleMaxText != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(scaleMaxText!, style: labelStyle),
                      ),
                    if (_showZero && width > 0)
                      Positioned(
                        left: (width * zeroFraction.clamp(0.0, 1.0)) - 6,
                        child: Text(scaleZeroText, style: labelStyle),
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
