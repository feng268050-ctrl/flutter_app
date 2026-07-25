import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';

/// Right-side material offset wheel (lws-ui materials_wheel_view).
final class QuickModeMaterialWheel extends StatefulWidget {
  const QuickModeMaterialWheel({
    super.key,
    required this.materials,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<MaterialType> materials;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  State<QuickModeMaterialWheel> createState() => _QuickModeMaterialWheelState();
}

final class _QuickModeMaterialWheelState extends State<QuickModeMaterialWheel> {
  late FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _clamped(widget.selectedIndex);
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(covariant QuickModeMaterialWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _clamped(widget.selectedIndex);
    if (oldWidget.materials.length != widget.materials.length ||
        next != _index) {
      _index = next;
      if (_controller.hasClients) {
        _controller.jumpToItem(next);
      } else {
        _controller.dispose();
        _controller = FixedExtentScrollController(initialItem: next);
      }
    }
  }

  int _clamped(int index) {
    if (widget.materials.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.materials.length - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('quick-mode-material-wheel'),
      width: QuickModePickerDimens.materialWidth,
      height: QuickModePickerDimens.materialHeight,
      child: widget.materials.isEmpty
          ? const SizedBox.shrink()
          : ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: QuickModePickerDimens.itemHeight,
              diameterRatio: 5,
              perspective: 0.002,
              offAxisFraction: 0.35,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() => _index = index);
                widget.onChanged(index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.materials.length,
                builder: (context, index) {
                  final selected = index == _index;
                  final distance = (index - _index).abs();
                  final alpha =
                      selected ? 1.0 : (1.0 - distance * 0.2).clamp(0.4, 1.0);
                  final endPad = QuickModePickerDimens.selectedTextPadding +
                      distance * (10 * QuickModePickerDimens.scale);
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: endPad),
                      child: Text(
                        widget.materials[index].englishName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(alpha),
                          fontSize: selected
                              ? QuickModePickerDimens.selectedTextSize
                              : QuickModePickerDimens.unselectedTextSize,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
