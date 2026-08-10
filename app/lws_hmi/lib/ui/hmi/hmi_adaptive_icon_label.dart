import 'dart:math' as math;

import 'package:flutter/material.dart';

enum HmiIconLabelLayoutMode { labelCentered, groupedCentered }

/// Geometry used by icon + label controls to select their layout from the
/// space they actually receive.
abstract final class HmiIconLabelLayout {
  static const iconLabelGap = 8.0;

  static const minimumIconLabelGap = 2.0;

  static double textWidth(
    BuildContext context,
    String label,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  static double groupedRequiredWidth({
    required double labelWidth,
    required double horizontalPadding,
    required double iconSize,
    required bool hasLeading,
    required bool hasTrailing,
    double gap = iconLabelGap,
  }) {
    final accessoryCount = (hasLeading ? 1 : 0) + (hasTrailing ? 1 : 0);
    return horizontalPadding * 2 +
        labelWidth +
        accessoryCount * iconSize +
        accessoryCount * gap;
  }

  static HmiIconLabelLayoutMode modeFor({
    required double maxWidth,
    required double labelWidth,
    required double buttonHeight,
    required double iconSize,
    required double horizontalPadding,
    double gap = iconLabelGap,
    double minimumGap = minimumIconLabelGap,
  }) {
    final edgeInset = math.max(0.0, (buttonHeight - iconSize) / 2).toDouble();
    final labelLeft = (maxWidth - labelWidth) / 2;
    final labelFitsContent = labelWidth + horizontalPadding * 2 <= maxWidth;
    final clearsLeading = labelLeft >= edgeInset + iconSize + minimumGap;
    return labelFitsContent && clearsLeading
        ? HmiIconLabelLayoutMode.labelCentered
        : HmiIconLabelLayoutMode.groupedCentered;
  }

  /// Preserves the design gap when it fits, then reduces only as far as the
  /// safe minimum before the selected text size is allowed to overflow.
  static double groupedGapFor({
    required double availableWidth,
    required double labelWidth,
    required double iconSize,
    required int accessoryCount,
    double gap = iconLabelGap,
    double minimumGap = minimumIconLabelGap,
  }) {
    if (accessoryCount == 0) {
      return 0;
    }
    final widthAtDesignGap = labelWidth + accessoryCount * (iconSize + gap);
    return widthAtDesignGap <= availableWidth ? gap : minimumGap;
  }
}

/// Automatically switches between a button-centered label with a fixed-left
/// icon and an icon + gap + label group centered as one unit.
///
/// Text is always rendered at the active [MediaQuery.textScaler]. When the
/// grouped form is still too narrow, only the label receives an ellipsis; no
/// scale-down transform is used.
final class HmiAdaptiveIconLabel extends StatelessWidget {
  const HmiAdaptiveIconLabel({
    super.key,
    required this.label,
    required this.style,
    required this.iconSize,
    required this.buttonHeight,
    required this.horizontalPadding,
    this.leading,
    this.trailing,
    this.allowGroupedTrailingInsetCollapse = false,
    this.gap = HmiIconLabelLayout.iconLabelGap,
    this.minimumGap = HmiIconLabelLayout.minimumIconLabelGap,
  });

  final String label;
  final TextStyle style;
  final double iconSize;
  final double buttonHeight;
  final double horizontalPadding;
  final Widget? leading;
  final Widget? trailing;
  final bool allowGroupedTrailingInsetCollapse;
  final double gap;
  final double minimumGap;

  @override
  Widget build(BuildContext context) {
    final labelWidth = HmiIconLabelLayout.textWidth(context, label, style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : HmiIconLabelLayout.groupedRequiredWidth(
                labelWidth: labelWidth,
                horizontalPadding: horizontalPadding,
                iconSize: iconSize,
                hasLeading: leading != null,
                hasTrailing: trailing != null,
                gap: gap,
              );
        final mode = leading != null && trailing == null
            ? HmiIconLabelLayout.modeFor(
                maxWidth: maxWidth,
                labelWidth: labelWidth,
                buttonHeight: buttonHeight,
                iconSize: iconSize,
                horizontalPadding: horizontalPadding,
                gap: gap,
                minimumGap: minimumGap,
              )
            : HmiIconLabelLayoutMode.groupedCentered;

        if (mode == HmiIconLabelLayoutMode.labelCentered) {
          final edgeInset =
              math.max(0.0, (buttonHeight - iconSize) / 2).toDouble();
          return SizedBox.expand(
            key: const ValueKey('hmi-icon-label-label-centered'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: _label(overflow: TextOverflow.visible)),
                Positioned(
                  left: edgeInset,
                  top: edgeInset,
                  width: iconSize,
                  height: iconSize,
                  child: _accessory(leading!),
                ),
              ],
            ),
          );
        }

        final collapseTrailingInset = allowGroupedTrailingInsetCollapse &&
            leading != null &&
            trailing == null;
        final contentWidth = math
            .max(
              0.0,
              maxWidth - horizontalPadding * (collapseTrailingInset ? 1 : 2),
            )
            .toDouble();
        final accessoryCount =
            (leading != null ? 1 : 0) + (trailing != null ? 1 : 0);
        final resolvedGap = HmiIconLabelLayout.groupedGapFor(
          availableWidth: contentWidth,
          labelWidth: labelWidth,
          iconSize: iconSize,
          accessoryCount: accessoryCount,
          gap: gap,
          minimumGap: minimumGap,
        );
        final groupWidth = labelWidth +
            accessoryCount * iconSize +
            accessoryCount * resolvedGap;
        final renderedWidth = math.min(groupWidth, contentWidth).toDouble();
        final overflows = groupWidth > contentWidth;
        return Padding(
          key: const ValueKey('hmi-icon-label-grouped-centered'),
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: collapseTrailingInset ? 0 : horizontalPadding,
          ),
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: renderedWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    _accessory(leading!),
                    SizedBox(width: resolvedGap),
                  ],
                  Expanded(
                    child: _label(
                      overflow: overflows
                          ? TextOverflow.ellipsis
                          : TextOverflow.visible,
                    ),
                  ),
                  if (trailing != null) ...[
                    SizedBox(width: resolvedGap),
                    _accessory(trailing!),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _accessory(Widget child) => SizedBox(
        width: iconSize,
        height: iconSize,
        child: IconTheme.merge(
          data: IconThemeData(size: iconSize, color: style.color),
          child: Center(child: child),
        ),
      );

  Text _label({required TextOverflow overflow}) => Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: overflow,
        textAlign: TextAlign.center,
        style: style,
      );
}
