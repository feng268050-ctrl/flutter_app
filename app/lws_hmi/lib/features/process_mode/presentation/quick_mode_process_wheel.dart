import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';

/// Quick Mode process-type offset wheel (lws-ui `wheel_view` + accent bands).
///
/// Selection bands stay fixed at page center; labels scroll / tap-to-position.
final class QuickModeProcessWheel extends StatelessWidget {
  const QuickModeProcessWheel({
    super.key,
    required this.processType,
    required this.onChanged,
  });

  final ProcessType processType;
  final ValueChanged<ProcessType> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = ProcessModeTokens.accentFor(processType);
    final hideSideAccent = processType == ProcessType.cncCutting;
    // CNC: only the solid accent (Android left fill is INVISIBLE). Keep width
    // ≤ cncGuideLeftInset so elevating the wheel above the guide cannot cover
    // the connection panel.
    final leftAccentWidth = hideSideAccent
        ? ProcessModeDimens.wheelAccentSolidWidth
        : ProcessModeDimens.wheelAccentBandWidth;
    final selectedIndex =
        QuickProcessWheelItems.types.indexOf(processType).clamp(
              0,
              QuickProcessWheelItems.types.length - 1,
            );

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: leftAccentWidth,
                height: ProcessModeDimens.wheelItemHeight,
                child: _WheelAccentBand(
                  accent: accent,
                  alignEnd: false,
                  showFillTail: !hideSideAccent,
                ),
              ),
            ),
          ),
          if (!hideSideAccent)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: ProcessModeDimens.wheelAccentBandWidth,
                  height: ProcessModeDimens.wheelItemHeight,
                  child: _WheelAccentBand(
                    accent: accent,
                    alignEnd: true,
                    showFillTail: true,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                key: const ValueKey('quick-mode-process-wheel'),
                width: ProcessModeDimens.wheelWidth,
                height: ProcessModeDimens.wheelHeight,
                child: QuickModeOffsetWheel(
                  itemCount: QuickProcessWheelItems.types.length,
                  selectedIndex: selectedIndex,
                  itemExtent: ProcessModeDimens.wheelItemHeight,
                  diameterRatio: ProcessModeDimens.wheelDiameterRatio,
                  perspective: ProcessModeDimens.wheelPerspective,
                  offAxisFraction: 0,
                  onChanged: (index) =>
                      onChanged(QuickProcessWheelItems.types[index]),
                  itemBuilder: (context, index, distance) {
                    final type = QuickProcessWheelItems.types[index];
                    final selected = distance < 0.5;
                    final alpha = selected
                        ? 1.0
                        : (1.0 - distance * 0.2).clamp(0.4, 1.0);
                    // Right-offset arc: left pad = |d|×10+24 (lws-ui mode wheel).
                    final startPad = selected
                        ? ProcessModeDimens.wheelSelectedPadding
                        : ProcessModeDimens.linearArcPad(distance);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(start: startPad),
                        child: Text(
                          ProcessModeLabels.wheelLabel(type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(alpha),
                            fontSize: selected
                                ? ProcessModeDimens.wheelSelectedTextSize
                                : ProcessModeDimens.wheelUnselectedTextSize,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            height: 1.1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left or right accent strip under the selected wheel row
/// (lws-ui `quick_mode_wheel_active_*`).
final class _WheelAccentBand extends StatelessWidget {
  const _WheelAccentBand({
    required this.accent,
    required this.alignEnd,
    required this.showFillTail,
  });

  final WorkModeAccent accent;
  final bool alignEnd;
  final bool showFillTail;

  @override
  Widget build(BuildContext context) {
    final solid = SizedBox(
      width: ProcessModeDimens.wheelAccentSolidWidth,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: accent.pressGradient),
      ),
    );
    final fill = Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: accent.pressGradient),
      ),
    );

    if (!showFillTail) {
      return alignEnd
          ? Row(children: [const Spacer(), solid])
          : Row(children: [solid, const Spacer()]);
    }

    return Row(
      children: alignEnd ? [fill, solid] : [solid, fill],
    );
  }
}
