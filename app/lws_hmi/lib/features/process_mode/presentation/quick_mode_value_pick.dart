import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';

/// Shared dimens for gear / thickness V2-style picks (lws-ui quick_mode_picker_*).
///
/// Values are fixed logical px for Flutter HMI (no runtime scale factor).
abstract final class QuickModePickerDimens {
  static const double pickWidth = 560 / 3; // 186.666…
  static const double titleHeight = 32;
  static const double titleTextSize = 58 / 3; // 19.333…
  static const double titleScaleGap = 16;
  /// lws-ui `quick_mode_picker_scale_height` / scale ImageView height.
  static const double scaleHeight = 402;
  static const double bottomPadding = 140 / 3; // 46.666…
  /// lws-ui gear/thickness scale ImageView width (`80.2dp`).
  static const double scaleImageWidth = 80.2;

  /// Visual shrink of the scale asset about its center (layout box unchanged).
  static const double scaleImageVisualScale = 0.88;
  static const double valueWheelWidth = 280 / 3; // 93.333…
  static const double materialWidth = 640 / 3; // 213.333…
  static const double materialHeight = 240;
  static const double itemHeight = 136 / 3; // 45.333…
  static const double selectedTextSize = 56 / 3; // 18.666…
  static const double unselectedTextSize = 16;
  static const double selectedTextPadding = 16;
  static const Color titleColor = Colors.white;

  static const double gearTitleOffset = -80 / 3; // -26.666…

  /// Selection band width — chip centered on the selected value.
  static const double accentWidth =
      selectedTextPadding * 2 + selectedTextSize * 2.5;

  /// Gap between scale chrome and the value wheel.
  static const double scaleValueGap = 8 / 3; // 2.666…

  /// Value wheel inset from the pick's outer (scale) side.
  static const double valueWheelInset = scaleImageWidth + scaleValueGap;

  /// Scale layout inner edge → thin bright ring (horizontal through center).
  static const double scaleToOuterFrameGap = 20;

  /// Pull scales inward so [scaleToOuterFrameGap] holds with value ring-hug:
  /// `accentWidth/2 + scaleValueGap + valueWheelWidth/2 - gap`.
  static const double scaleInwardInset =
      accentWidth / 2 + scaleValueGap + valueWheelWidth / 2 - scaleToOuterFrameGap;

  /// Extra end padding per wheel distance unit (material arc, lws-ui linear).
  static const double materialArcPadPerDistance = 20 / 3; // 6.666…

  /// lws-ui gear/thickness wheel cylinder (ListWheelScrollView).
  static const double wheelDiameterRatio = 5.5;
  static const double wheelPerspective = 0.002;

  /// lws-ui OffsetWheelBuilder.builderOffsetGearOffset:
  /// `abs(d)^2 * 8 + 24` (design dp → logical px here).
  static double unselectedOffset(double distance) =>
      distance * distance * 8 + 24;

  /// Selected-value X from page center (accent midline, just outside the ring).
  static double gearValueCenterFromPageCenter(double highlightR) =>
      -highlightR - accentWidth / 2;

  static double thicknessValueCenterFromPageCenter(double highlightR) =>
      highlightR + accentWidth / 2;

  /// Pick widget center X so the value-wheel center lands on [valueCenter].
  static double gearPickCenterFromPageCenter(double highlightR) {
    final valueCenter = gearValueCenterFromPageCenter(highlightR);
    final valueInPick = valueWheelInset + valueWheelWidth / 2;
    return valueCenter - (valueInPick - pickWidth / 2);
  }

  static double thicknessPickCenterFromPageCenter(double highlightR) {
    final valueCenter = thicknessValueCenterFromPageCenter(highlightR);
    final valueInPick = pickWidth - valueWheelInset - valueWheelWidth / 2;
    return valueCenter - (valueInPick - pickWidth / 2);
  }
}

/// Vertical value wheel with scale chrome (GearPickV2 / ThicknessPickV2).
///
/// Scale image stays on the pick's vertical center (page places that on the
/// dashboard circle). Selected values / accent chip are lifted by
/// [ProcessModeDimens.quickSelectorNudgeY] to share the mode / material
/// selection midline. Unselected rows arc toward the scale (lws-ui OffsetWheel
/// padding direction).
final class QuickModeValuePick extends StatelessWidget {
  const QuickModeValuePick({
    super.key,
    required this.processType,
    required this.title,
    required this.values,
    required this.selectedIndex,
    required this.labelOf,
    required this.onChanged,
    required this.scaleOnLeft,
  });

  final ProcessType processType;
  final String title;
  final List<double> values;
  final int selectedIndex;
  final String Function(double value) labelOf;
  final ValueChanged<int> onChanged;
  final bool scaleOnLeft;

  @override
  Widget build(BuildContext context) {
    final accent = ProcessModeTokens.accentFor(processType);
    return SizedBox(
      width: QuickModePickerDimens.pickWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: QuickModePickerDimens.titleHeight,
            child: Transform.translate(
              offset: Offset(
                scaleOnLeft ? QuickModePickerDimens.gearTitleOffset : 0,
                0,
              ),
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: QuickModePickerDimens.titleColor,
                    fontSize: QuickModePickerDimens.titleTextSize,
                    height: 1,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: QuickModePickerDimens.titleScaleGap),
          SizedBox(
            height: QuickModePickerDimens.scaleHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: scaleOnLeft
                      ? QuickModePickerDimens.scaleInwardInset
                      : null,
                  right: scaleOnLeft
                      ? null
                      : QuickModePickerDimens.scaleInwardInset,
                  top: 0,
                  bottom: 0,
                  width: QuickModePickerDimens.scaleImageWidth,
                  child: Transform.scale(
                    scale: QuickModePickerDimens.scaleImageVisualScale,
                    alignment: Alignment.center,
                    child: Image.asset(
                      scaleOnLeft
                          ? ProcessModeAssets.scaleLeft
                          : ProcessModeAssets.scaleRight,
                      key: ValueKey(
                        scaleOnLeft
                            ? 'quick-mode-scale-left'
                            : 'quick-mode-scale-right',
                      ),
                      width: QuickModePickerDimens.scaleImageWidth,
                      height: QuickModePickerDimens.scaleHeight,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: scaleOnLeft
                      ? QuickModePickerDimens.valueWheelInset
                      : null,
                  right: scaleOnLeft
                      ? null
                      : QuickModePickerDimens.valueWheelInset,
                  width: QuickModePickerDimens.valueWheelWidth,
                  child: Transform.translate(
                    offset: const Offset(
                      0,
                      ProcessModeDimens.quickSelectorNudgeY,
                    ),
                    child: QuickModeOffsetWheel(
                      itemCount: values.length,
                      selectedIndex: selectedIndex,
                      itemExtent: QuickModePickerDimens.itemHeight,
                      diameterRatio: QuickModePickerDimens.wheelDiameterRatio,
                      perspective: QuickModePickerDimens.wheelPerspective,
                      // Keep cylinder on-axis so the selected digit stays on the
                      // accent midline; horizontal arc is EdgeInsets padding
                      // (lws-ui OffsetWheel left/right pad).
                      offAxisFraction: 0,
                      onChanged: onChanged,
                      fixedAccent: _ValueAccentChip(accent: accent),
                      itemBuilder: (context, index, distance) {
                        return _ValuePickItem(
                          label: labelOf(values[index]),
                          distance: distance,
                          scaleOnLeft: scaleOnLeft,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: QuickModePickerDimens.bottomPadding),
        ],
      ),
    );
  }
}

/// Accent chip locked to the value-wheel viewport center.
final class _ValueAccentChip extends StatelessWidget {
  const _ValueAccentChip({required this.accent});

  final WorkModeAccent accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('quick-mode-value-pick-accent'),
      width: QuickModePickerDimens.accentWidth,
      height: QuickModePickerDimens.itemHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              accent.pressCenter.withOpacity(0),
              accent.pressCenter,
              accent.pressCenter.withOpacity(0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

final class _ValuePickItem extends StatelessWidget {
  const _ValuePickItem({
    required this.label,
    required this.distance,
    required this.scaleOnLeft,
  });

  final String label;
  final double distance;
  final bool scaleOnLeft;

  @override
  Widget build(BuildContext context) {
    final atCenter = distance < 0.5;
    final alpha = atCenter ? 1.0 : (1.0 - distance * 0.2).clamp(0.4, 1.0);
    final text = Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(alpha),
        fontSize: atCenter
            ? QuickModePickerDimens.selectedTextSize
            : QuickModePickerDimens.unselectedTextSize,
        fontWeight: atCenter ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    // Selected / center row stays on the accent midline (特效中心).
    if (atCenter) {
      return SizedBox(
        height: QuickModePickerDimens.itemHeight,
        child: Center(child: text),
      );
    }

    // lws-ui OffsetWheelAdapter unselected arc via one-sided padding:
    // gear pad left → toward dashboard; thickness pad right.
    final offset = QuickModePickerDimens.unselectedOffset(distance);
    final align =
        scaleOnLeft ? Alignment.centerLeft : Alignment.centerRight;
    return Align(
      alignment: align,
      child: Padding(
        padding: scaleOnLeft
            ? EdgeInsets.only(left: offset)
            : EdgeInsets.only(right: offset),
        child: SizedBox(
          height: QuickModePickerDimens.itemHeight,
          child: Align(alignment: align, child: text),
        ),
      ),
    );
  }
}

/// Integer gear pick (wraps [QuickModeValuePick]).
final class QuickModeGearPick extends StatelessWidget {
  const QuickModeGearPick({
    super.key,
    required this.processType,
    required this.gears,
    required this.selectedIndex,
    required this.onChanged,
  });

  final ProcessType processType;
  final List<int> gears;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return QuickModeValuePick(
      key: const ValueKey('quick-mode-gear-pick'),
      processType: processType,
      title: 'Gear',
      values: [for (final gear in gears) gear.toDouble()],
      selectedIndex: selectedIndex,
      labelOf: (value) => value.round().toString(),
      onChanged: onChanged,
      scaleOnLeft: true,
    );
  }
}

/// Thickness or swing-width pick.
final class QuickModeDimensionPick extends StatelessWidget {
  const QuickModeDimensionPick({
    super.key,
    required this.processType,
    required this.title,
    required this.dimensions,
    required this.selectedIndex,
    required this.onChanged,
  });

  final ProcessType processType;
  final String title;
  final List<double> dimensions;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return QuickModeValuePick(
      key: const ValueKey('quick-mode-dimension-pick'),
      processType: processType,
      title: title,
      values: dimensions,
      selectedIndex: selectedIndex,
      labelOf: _formatMm,
      onChanged: onChanged,
      scaleOnLeft: false,
    );
  }

  static String _formatMm(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    final fixed = value.toStringAsFixed(2);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
