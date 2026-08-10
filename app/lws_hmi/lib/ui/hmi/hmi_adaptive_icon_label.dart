import 'dart:math' as math;

import 'package:flutter/material.dart';

enum HmiIconLabelLayoutMode { labelCentered, groupedCentered }

/// Geometry used by icon + label controls to select their layout from the
/// space they actually receive.
abstract final class HmiIconLabelLayout {
  static const iconLabelGap = 8.0;

  static const minimumIconLabelGap = 2.0;

  /// Floor for equal side insets when centering an icon+label group.
  static const minimumGroupedHorizontalPadding = 8.0;

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
    // Painter can undershoot real glyph advance; keep a small slack.
    return painter.width + 2;
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

  static double groupedCoreWidth({
    required double labelWidth,
    required double iconSize,
    required int accessoryCount,
    required double gap,
  }) {
    return labelWidth +
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

  /// Equal L/R inset so [icon+gap+label] sits as one centered group.
  ///
  /// Shrinks from [preferredPadding] only when needed to keep the full label;
  /// returns the resolved padding and whether the label still overflows.
  static ({double padding, double gap, bool overflows}) resolveGroupedInsets({
    required double maxWidth,
    required double labelWidth,
    required double iconSize,
    required int accessoryCount,
    required double preferredPadding,
    double gap = iconLabelGap,
    double minimumGap = minimumIconLabelGap,
    double minimumPadding = minimumGroupedHorizontalPadding,
  }) {
    final minPad = math.min(minimumPadding, preferredPadding);
    double core(double g) => groupedCoreWidth(
          labelWidth: labelWidth,
          iconSize: iconSize,
          accessoryCount: accessoryCount,
          gap: g,
        );

    // Prefer design gap + preferred padding when there is room.
    if (core(gap) + preferredPadding * 2 <= maxWidth) {
      final pad = (maxWidth - core(gap)) / 2;
      return (padding: pad, gap: gap, overflows: false);
    }

    // Keep design gap; shrink equal side insets down to [minPad].
    if (core(gap) + minPad * 2 <= maxWidth) {
      final pad = (maxWidth - core(gap)) / 2;
      return (padding: pad, gap: gap, overflows: false);
    }

    // Minimum gap + equal leftover (may be below minPad, including 0).
    final coreMin = core(minimumGap);
    if (coreMin <= maxWidth) {
      final pad = (maxWidth - coreMin) / 2;
      return (padding: pad, gap: minimumGap, overflows: false);
    }

    return (padding: 0, gap: minimumGap, overflows: true);
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
    this.forceGroupedCentered = false,
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

  /// When true, always center icon+label as one group with equal side insets
  /// (Quick Auto Wire Feed / Manual Gas outline chrome).
  final bool forceGroupedCentered;
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
        final mode = forceGroupedCentered
            ? HmiIconLabelLayoutMode.groupedCentered
            : (leading != null && trailing == null
                ? HmiIconLabelLayout.modeFor(
                    maxWidth: maxWidth,
                    labelWidth: labelWidth,
                    buttonHeight: buttonHeight,
                    iconSize: iconSize,
                    horizontalPadding: horizontalPadding,
                    gap: gap,
                    minimumGap: minimumGap,
                  )
                : HmiIconLabelLayoutMode.groupedCentered);

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

        final accessoryCount =
            (leading != null ? 1 : 0) + (trailing != null ? 1 : 0);

        if (allowGroupedTrailingInsetCollapse &&
            leading != null &&
            trailing == null) {
          // Legacy: keep left preferred inset, collapse trailing for more text.
          final contentWidth =
              math.max(0.0, maxWidth - horizontalPadding).toDouble();
          final resolvedGap = HmiIconLabelLayout.groupedGapFor(
            availableWidth: contentWidth,
            labelWidth: labelWidth,
            iconSize: iconSize,
            accessoryCount: accessoryCount,
            gap: gap,
            minimumGap: minimumGap,
          );
          final groupWidth = HmiIconLabelLayout.groupedCoreWidth(
            labelWidth: labelWidth,
            iconSize: iconSize,
            accessoryCount: accessoryCount,
            gap: resolvedGap,
          );
          final renderedWidth = math.min(groupWidth, contentWidth).toDouble();
          final overflows = groupWidth > contentWidth;
          return Padding(
            key: const ValueKey('hmi-icon-label-grouped-centered'),
            padding: EdgeInsets.only(left: horizontalPadding),
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: renderedWidth,
                child: _groupedRow(
                  resolvedGap: resolvedGap,
                  overflows: overflows,
                ),
              ),
            ),
          );
        }

        final insets = HmiIconLabelLayout.resolveGroupedInsets(
          maxWidth: maxWidth,
          labelWidth: labelWidth,
          iconSize: iconSize,
          accessoryCount: accessoryCount,
          preferredPadding: horizontalPadding,
          gap: gap,
          minimumGap: minimumGap,
        );
        final contentWidth =
            math.max(0.0, maxWidth - insets.padding * 2).toDouble();
        final groupWidth = HmiIconLabelLayout.groupedCoreWidth(
          labelWidth: labelWidth,
          iconSize: iconSize,
          accessoryCount: accessoryCount,
          gap: insets.gap,
        );
        final renderedWidth = math.min(groupWidth, contentWidth).toDouble();
        return Padding(
          key: const ValueKey('hmi-icon-label-grouped-centered'),
          padding: EdgeInsets.symmetric(horizontal: insets.padding),
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: renderedWidth,
              child: _groupedRow(
                resolvedGap: insets.gap,
                overflows: insets.overflows,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _groupedRow({
    required double resolvedGap,
    required bool overflows,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          _accessory(leading!),
          SizedBox(width: resolvedGap),
        ],
        if (overflows)
          Expanded(
            child: _label(overflow: TextOverflow.ellipsis),
          )
        else
          _label(overflow: TextOverflow.visible),
        if (trailing != null) ...[
          SizedBox(width: resolvedGap),
          _accessory(trailing!),
        ],
      ],
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
