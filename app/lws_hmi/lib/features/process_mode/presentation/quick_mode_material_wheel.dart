import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';

/// Right-side material offset wheel (lws-ui materials_wheel_view).
final class QuickModeMaterialWheel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('quick-mode-material-wheel'),
      width: QuickModePickerDimens.materialWidth,
      height: QuickModePickerDimens.materialHeight,
      child: QuickModeOffsetWheel(
        itemCount: materials.length,
        selectedIndex: selectedIndex,
        itemExtent: QuickModePickerDimens.itemHeight,
        diameterRatio: 5,
        perspective: 0.002,
        offAxisFraction: 0.35,
        onChanged: onChanged,
        itemBuilder: (context, index, distance) {
          final selected = distance < 0.5;
          final alpha =
              selected ? 1.0 : (1.0 - distance * 0.2).clamp(0.4, 1.0);
          final endPad = QuickModePickerDimens.selectedTextPadding +
              distance * QuickModePickerDimens.materialArcPadPerDistance;
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: endPad),
              child: Text(
                materials[index].englishName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(alpha),
                  fontSize: selected
                      ? QuickModePickerDimens.selectedTextSize
                      : QuickModePickerDimens.unselectedTextSize,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
