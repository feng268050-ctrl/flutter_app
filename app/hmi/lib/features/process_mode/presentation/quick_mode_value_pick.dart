import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';

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
  /// Outward inset for scale chrome; mirrored L/R about screen center.
  static const double scaleEdgeOffset = -25 * scale;
  static const double gearValueOffset = 20 * scale;
  static const double thicknessValueOffset = 20 * scale;

  static double unselectedOffset(int distance) =>
      (distance * distance * 8 + 24) * scale;
}

/// Vertical value wheel with scale chrome (GearPickV2 / ThicknessPickV2).
final class QuickModeValuePick extends StatefulWidget {
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
  State<QuickModeValuePick> createState() => _QuickModeValuePickState();
}

final class _QuickModeValuePickState extends State<QuickModeValuePick> {
  late FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _clampedIndex(widget.selectedIndex);
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(covariant QuickModeValuePick oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _clampedIndex(widget.selectedIndex);
    final listChanged = oldWidget.values.length != widget.values.length;
    if (listChanged || next != _index) {
      _index = next;
      if (_controller.hasClients) {
        _controller.jumpToItem(next);
      } else {
        _controller.dispose();
        _controller = FixedExtentScrollController(initialItem: next);
      }
    }
  }

  int _clampedIndex(int index) {
    if (widget.values.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.values.length - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ProcessModeTokens.accentFor(widget.processType);
    return SizedBox(
      width: QuickModePickerDimens.pickWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: QuickModePickerDimens.titleHeight,
            child: Transform.translate(
              offset: Offset(
                widget.scaleOnLeft ? QuickModePickerDimens.gearTitleOffset : 0,
                0,
              ),
              child: Center(
                child: Text(
                  widget.title,
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
                // Scale chrome — mirrored about screen center (same edge inset).
                Positioned(
                  left: widget.scaleOnLeft
                      ? QuickModePickerDimens.scaleEdgeOffset
                      : null,
                  right: widget.scaleOnLeft
                      ? null
                      : QuickModePickerDimens.scaleEdgeOffset,
                  top: 0,
                  bottom: 0,
                  child: Image.asset(
                    widget.scaleOnLeft
                        ? ProcessModeAssets.scaleLeft
                        : ProcessModeAssets.scaleRight,
                    width: QuickModePickerDimens.scaleImageWidth,
                    fit: BoxFit.fitHeight,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                // Value wheel — selected row centered on the same midline.
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: widget.scaleOnLeft
                      ? QuickModePickerDimens.gearValueOffset
                      : null,
                  right: widget.scaleOnLeft
                      ? null
                      : -QuickModePickerDimens.thicknessValueOffset,
                  width: QuickModePickerDimens.valueWheelWidth,
                  child: widget.values.isEmpty
                      ? const SizedBox.shrink()
                      : ListWheelScrollView.useDelegate(
                          controller: _controller,
                          itemExtent: QuickModePickerDimens.itemHeight,
                          diameterRatio: 5.5,
                          perspective: 0.002,
                          offAxisFraction: widget.scaleOnLeft ? -0.4 : 0.4,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() => _index = index);
                            widget.onChanged(index);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: widget.values.length,
                            builder: (context, index) {
                              final selected = index == _index;
                              final distance = (index - _index).abs();
                              final alpha = selected
                                  ? 1.0
                                  : (1.0 - distance * 0.2).clamp(0.4, 1.0);
                              final pad =
                                  QuickModePickerDimens.selectedTextPadding;
                              final sidePad = selected
                                  ? pad
                                  : QuickModePickerDimens.unselectedOffset(
                                      distance);
                              // Selected: center number in the highlight band.
                              // Unselected: keep side offset toward the scale.
                              return Align(
                                alignment: selected
                                    ? Alignment.center
                                    : (widget.scaleOnLeft
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight),
                                child: SizedBox(
                                  height: QuickModePickerDimens.itemHeight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? accent.pressGradient
                                          : null,
                                    ),
                                    child: Align(
                                      alignment: selected
                                          ? Alignment.center
                                          : (widget.scaleOnLeft
                                              ? Alignment.centerLeft
                                              : Alignment.centerRight),
                                      child: Padding(
                                        padding: selected
                                            ? EdgeInsets.symmetric(
                                                horizontal: pad,
                                              )
                                            : EdgeInsets.only(
                                                left: widget.scaleOnLeft
                                                    ? sidePad
                                                    : 0,
                                                right: widget.scaleOnLeft
                                                    ? 0
                                                    : sidePad,
                                              ),
                                        child: Text(
                                          widget.labelOf(widget.values[index]),
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(alpha),
                                            fontSize: selected
                                                ? QuickModePickerDimens
                                                    .selectedTextSize
                                                : QuickModePickerDimens
                                                    .unselectedTextSize,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
