import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// lws-ui `ImeKeyCap.AlternatePopupOffsetAboveKey`.
const double kCyberImeAlternatePopupOffsetAboveKey = 56;

/// lws-ui `ime_key_min_height` / popup cell `defaultMinSize`.
const double kCyberImeKeyMinHeight = 44;

/// lws-ui `ime_key_gap` between popup option cells.
const double kCyberImeKeyGap = 12;

/// lws-ui `ime_key_alternate_popup_text_size`.
const double kCyberImeAlternatePopupTextSize = 36;

/// Floating alternate-key popup state (anchored above a keycap).
class CyberImeAlternatePopupData {
  const CyberImeAlternatePopupData({
    required this.options,
    required this.selectedIndex,
    required this.anchor,
  });

  final List<String> options;
  final int selectedIndex;

  /// Popup top-center in the IME overlay [Stack] local coordinates.
  final Offset anchor;

  CyberImeAlternatePopupData copyWith({
    List<String>? options,
    int? selectedIndex,
    Offset? anchor,
  }) {
    return CyberImeAlternatePopupData(
      options: options ?? this.options,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      anchor: anchor ?? this.anchor,
    );
  }
}

/// lws-ui `ImeAlternatePopup` — compact frost strip of option cells.
class CyberImeAlternatePopup extends StatelessWidget {
  const CyberImeAlternatePopup({
    super.key,
    required this.options,
    required this.selectedIndex,
  });

  final List<String> options;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xE618181A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CyberColors.borderHighlight, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: kCyberImeKeyGap),
              _CyberImeAlternatePopupCell(
                label: options[i],
                selected: i == selectedIndex,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CyberImeAlternatePopupCell extends StatelessWidget {
  const _CyberImeAlternatePopupCell({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius =
        BorderRadius.circular(CyberDimens.rectangleButtonCornerRadius);
    final border = selected
        ? CyberColors.buttonPrimaryAccent
        : CyberColors.lightBorderHighlight;
    final gradient = selected
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xE6FF9A5C),
              Color(0xD9FF8A4D),
              Color(0xCCFF7A3D),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CyberColors.lightFillTop,
              CyberColors.lightFillMid,
              CyberColors.lightFillBottom,
            ],
          );

    return Container(
      constraints: const BoxConstraints(
        minWidth: kCyberImeKeyMinHeight,
        minHeight: kCyberImeKeyMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: border, width: CyberDimens.buttonStrokeWidth),
        gradient: gradient,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? Colors.white : CyberColors.textPrimary,
          fontSize: kCyberImeAlternatePopupTextSize,
          fontWeight: FontWeight.w500,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
