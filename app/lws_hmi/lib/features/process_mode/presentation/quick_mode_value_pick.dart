import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';

/// Shared dimens for gear / thickness V2-style picks (lws-ui quick_mode_picker_*).
abstract final class QuickModePickerDimens {
  static const double scale = 2 / 3;
  static const double pickWidth = 280 * scale;
  static const double titleHeight = 48 * scale;
  static const double titleTextSize = 29 * scale;
  static const double titleScaleGap = 24 * scale;
  static const double scaleHeight = 402 * scale;
  static const double bottomPadding = 70 * scale;
  static const double scaleImageWidth = 80.2 * scale;
  static const double valueWheelWidth = 140 * scale;
  static const double materialWidth = 320 * scale;
  static const double materialHeight = 360 * scale;
  static const double itemHeight = 68 * scale;
  static const double selectedTextSize = 28 * scale;
  static const double unselectedTextSize = 24 * scale;
  static const double selectedTextPadding = 24 * scale;
  static const Color titleColor = Colors.white;

  static const double gearTitleOffset = -40 * scale;

  /// Selection band width — chip centered on the selected value.
  static const double accentWidth =
      selectedTextPadding * 2 + selectedTextSize * 2.5;

  /// Gap between scale chrome and the value wheel.
  static const double scaleValueGap = 4 * scale;

  /// Value wheel inset from the pick's outer (scale) side.
  static const double valueWheelInset = scaleImageWidth + scaleValueGap;

  /// Pull both scales inward toward the value / screen center (design 70dp).
  static const double scaleInwardInset = 70 * scale;

  /// lws-ui gear/thickness wheel cylinder (offset arc via item padding).
  static const double wheelDiameterRatio = 5.5;
  static const double wheelPerspective = 0.002;

  static double unselectedOffset(double distance) =>
      (distance * distance * 8 + 24) * scale;

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
/// Selected numbers sit on the local accent midline; unselected rows arc
/// toward the scale (lws-ui OffsetWheel padding direction).
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
                  child: Image.asset(
                    scaleOnLeft
                        ? ProcessModeAssets.scaleLeft
                        : ProcessModeAssets.scaleRight,
                    width: QuickModePickerDimens.scaleImageWidth,
                    fit: BoxFit.fitHeight,
                    filterQuality: FilterQuality.medium,
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
                  child: QuickModeOffsetWheel(
                    itemCount: values.length,
                    selectedIndex: selectedIndex,
                    itemExtent: QuickModePickerDimens.itemHeight,
                    diameterRatio: QuickModePickerDimens.wheelDiameterRatio,
                    perspective: QuickModePickerDimens.wheelPerspective,
                    // Keep cylinder on-axis so the selected digit stays on the
                    // accent midline; horizontal arc is Transform (lws-ui
                    // OffsetWheel pad direction: gear → right, thickness → left).
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
    // lws-ui OffsetWheelBuilder:
    // - Gear offsetDirection=1 (right): unselected pad *left* → text arcs
    //   bottom-right ↔ top-right (toward dashboard).
    // - Thickness offsetDirection=0 (left): unselected pad *right* → text
    //   arcs bottom-left ↔ top-left.
    final sidePad = atCenter
        ? 0.0
        : QuickModePickerDimens.unselectedOffset(distance);
    final arcX = scaleOnLeft ? sidePad : -sidePad;
    return Transform.translate(
      offset: Offset(arcX, 0),
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: QuickModePickerDimens.itemHeight,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(alpha),
                fontSize: atCenter
                    ? QuickModePickerDimens.selectedTextSize
                    : QuickModePickerDimens.unselectedTextSize,
                fontWeight: atCenter ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
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
