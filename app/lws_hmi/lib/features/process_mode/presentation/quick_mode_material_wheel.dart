import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    // Match the right solid accent band so selected copy sits on the peak.
    const labelBandWidth = ProcessModeDimens.wheelAccentSolidWidth;
    return SizedBox(
      key: const ValueKey('quick-mode-material-wheel'),
      width: labelBandWidth,
      height: QuickModePickerDimens.materialHeight,
      child: QuickModeOffsetWheel(
        itemCount: materials.length,
        selectedIndex: selectedIndex,
        itemExtent: QuickModePickerDimens.itemHeight,
        diameterRatio: QuickModePickerDimens.wheelDiameterRatio,
        perspective: QuickModePickerDimens.wheelPerspective,
        offAxisFraction: 0,
        onChanged: onChanged,
        itemBuilder: (context, index, distance) {
          final selected = distance < 0.5;
          final alpha =
              selected ? 1.0 : (1.0 - distance * 0.2).clamp(0.4, 1.0);
          final label = Text(
            materials[index].localizedLabel(l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withOpacity(alpha),
              fontSize: selected
                  ? QuickModePickerDimens.materialSelectedTextSize
                  : QuickModePickerDimens.materialUnselectedTextSize,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          );
          // Right-align all rows (lws-ui materials left-offset + Gravity.END).
          // Selected: equal L/R pad; unselected: end pad = |d|×10+24.
          final endPad = selected
              ? QuickModePickerDimens.arcSelectedPad
              : QuickModePickerDimens.linearArcPad(distance);
          final startPad =
              selected ? QuickModePickerDimens.arcSelectedPad : 0.0;
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: startPad,
                end: endPad,
              ),
              child: label,
            ),
          );
        },
      ),
    );
  }
}
