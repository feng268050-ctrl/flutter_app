import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// lws-ui `ImeKeyCap.AlternatePopupOffsetAboveKey`.
///
/// Preferred distance from the key’s top edge up to the popup’s top edge.
/// When the measured popup is taller, the top is lifted further so the popup
/// does not overlap the keycap.
const double kCyberImeAlternatePopupOffsetAboveKey = 56;

/// Minimum gap between the alternate popup and the screen (stack) edges.
const double kCyberImeAlternatePopupEdgeInset = 2;

/// lws-ui `ime_key_min_height` / popup cell `defaultMinSize`.
const double kCyberImeKeyMinHeight = 44;

/// lws-ui `ime_key_gap` between popup option cells.
const double kCyberImeKeyGap = 12;

/// lws-ui `ime_key_primary_text_size` (28sp); line height matches font size.
const double kCyberImeKeyPrimaryTextSize = 28;

/// lws-ui `ime_key_secondary_hint_text_size` face hint (cyber_ime uses 18).
const double kCyberImeKeySecondaryHintTextSize = 18;

/// lws-ui `ime_key_alternate_popup_text_size` (28sp).
const double kCyberImeAlternatePopupTextSize = 28;

/// Clamps a preferred top-center X so [childWidth] stays inset from [parentWidth].
double cyberImeClampAlternatePopupLeft({
  required double preferredCenterX,
  required double childWidth,
  required double parentWidth,
  double edgeInset = kCyberImeAlternatePopupEdgeInset,
}) {
  if (parentWidth <= 0 || childWidth <= 0) {
    return preferredCenterX - childWidth / 2;
  }
  final maxLeft = parentWidth - childWidth - edgeInset;
  if (maxLeft <= edgeInset) {
    // Popup wider than the safe area — center in the parent.
    return (parentWidth - childWidth) / 2;
  }
  return (preferredCenterX - childWidth / 2).clamp(edgeInset, maxLeft);
}

/// Top Y for the popup given the key’s top Y and the measured popup height.
double cyberImeAlternatePopupTop({
  required double keyTopY,
  required double popupHeight,
  double offsetAboveKey = kCyberImeAlternatePopupOffsetAboveKey,
  double edgeInset = kCyberImeAlternatePopupEdgeInset,
  double parentHeight = double.infinity,
}) {
  // Lift at least [offsetAboveKey]; never overlap the keycap.
  final lift = math.max(offsetAboveKey, popupHeight);
  var top = keyTopY - lift;
  if (parentHeight.isFinite && popupHeight > 0) {
    final maxTop = parentHeight - popupHeight - edgeInset;
    if (maxTop > edgeInset) {
      top = top.clamp(edgeInset, maxTop);
    } else {
      top = edgeInset;
    }
  } else if (top < edgeInset) {
    top = edgeInset;
  }
  return top;
}

/// Positions [CyberImeAlternatePopup] above [preferredKeyTopCenter], clamped.
class CyberImeAlternatePopupPositionDelegate extends SingleChildLayoutDelegate {
  CyberImeAlternatePopupPositionDelegate({
    required this.preferredKeyTopCenter,
    this.edgeInset = kCyberImeAlternatePopupEdgeInset,
    this.offsetAboveKey = kCyberImeAlternatePopupOffsetAboveKey,
  });

  /// Keycap top-center in the parent (popup is laid out above this point).
  final Offset preferredKeyTopCenter;
  final double edgeInset;
  final double offsetAboveKey;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // Must stay unbounded on both axes so Material/Container shrink-wrap to the
    // option strip. A maxHeight from the overlay would stretch the popup to the
    // full screen and break vertical anchoring.
    return const BoxConstraints();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = cyberImeClampAlternatePopupLeft(
      preferredCenterX: preferredKeyTopCenter.dx,
      childWidth: childSize.width,
      parentWidth: size.width,
      edgeInset: edgeInset,
    );
    final top = cyberImeAlternatePopupTop(
      keyTopY: preferredKeyTopCenter.dy,
      popupHeight: childSize.height,
      offsetAboveKey: offsetAboveKey,
      edgeInset: edgeInset,
      parentHeight: size.height,
    );
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(
    covariant CyberImeAlternatePopupPositionDelegate oldDelegate,
  ) {
    return preferredKeyTopCenter != oldDelegate.preferredKeyTopCenter ||
        edgeInset != oldDelegate.edgeInset ||
        offsetAboveKey != oldDelegate.offsetAboveKey;
  }
}

/// Floating alternate-key popup state (anchored above a keycap).
class CyberImeAlternatePopupData {
  const CyberImeAlternatePopupData({
    required this.options,
    required this.selectedIndex,
    required this.anchor,
  });

  final List<String> options;
  final int selectedIndex;

  /// Keycap top-center in the IME overlay [Stack] local coordinates.
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
