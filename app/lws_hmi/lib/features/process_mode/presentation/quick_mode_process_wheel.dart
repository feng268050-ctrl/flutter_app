import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_offset_wheel.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';

/// Quick Mode process-type offset wheel (lws-ui `wheel_view` + accent bands).
///
/// Selection bands stay fixed at page center; labels scroll / tap-to-position.
/// When [showAccents] is false (Laser Enable frost plate), only the label wheel
/// is painted — accents are hidden like lws-ui `laserStatus` INVISIBLE bands.
final class QuickModeProcessWheel extends StatelessWidget {
  const QuickModeProcessWheel({
    super.key,
    required this.processType,
    required this.onChanged,
    this.showAccents = true,
  });

  final ProcessType processType;
  final ValueChanged<ProcessType> onChanged;

  /// When false, omit left/right accent bands (Laser Enable BlurUtils plate).
  final bool showAccents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hideSideAccent =
        !showAccents || processType == ProcessType.cncCutting;
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

    // Selected copy may use up to the gear scale (minus a small gap). Do not
    // clamp to the solid accent width — that ellipsized "Continuous Welding".
    final pageSize = MediaQuery.sizeOf(context);
    final highlightR = ProcessModeDimens.outerHighlightRadiusFor(pageSize);
    final scaleLeft = pageSize.width / 2 +
        QuickModePickerDimens.gearPickCenterFromPageCenter(highlightR) -
        QuickModePickerDimens.pickWidth / 2 +
        QuickModePickerDimens.scaleInwardInset;
    final roomToScale = (scaleLeft -
            ProcessModeDimens.wheelSelectedPadding -
            ProcessModeDimens.wheelLabelToScaleGap)
        .clamp(80.0, pageSize.width / 2)
        .toDouble();
    // Frost plate keeps the smaller lws-ui wheel width; otherwise widen the
    // label band so selected text is not clipped by the solid accent box.
    // CNC: keep the band inside [cncGuideLeftInset] so Connection Guide cannot
    // cover neighbor labels (Stack paints the guide above the wheel).
    var labelBandWidth = showAccents
        ? (ProcessModeDimens.wheelAccentSolidWidth >
                roomToScale + ProcessModeDimens.wheelSelectedPadding
            ? ProcessModeDimens.wheelAccentSolidWidth
            : roomToScale + ProcessModeDimens.wheelSelectedPadding)
        : ProcessModeDimens.wheelWidth;
    if (hideSideAccent && showAccents) {
      labelBandWidth = math.min(
        labelBandWidth,
        ProcessModeDimens.cncGuideLeftInset,
      );
    }
    final selectedTextMaxWidth = showAccents
        ? (hideSideAccent
            ? math.max(
                40.0,
                labelBandWidth - ProcessModeDimens.wheelSelectedPadding,
              )
            : roomToScale)
        : labelBandWidth - ProcessModeDimens.wheelSelectedPadding;

    final wheel = SizedBox(
      key: const ValueKey('quick-mode-process-wheel'),
      width: labelBandWidth,
      height: ProcessModeDimens.wheelHeight,
      child: QuickModeOffsetWheel(
        itemCount: QuickProcessWheelItems.types.length,
        selectedIndex: selectedIndex,
        itemExtent: ProcessModeDimens.wheelItemHeight,
        diameterRatio: ProcessModeDimens.wheelDiameterRatio,
        perspective: ProcessModeDimens.wheelPerspective,
        offAxisFraction: 0,
        onChanged: (index) => onChanged(QuickProcessWheelItems.types[index]),
        itemBuilder: (context, index, signedDistance) {
          final distance = signedDistance.abs();
          final type = QuickProcessWheelItems.types[index];
          final selected = distance < 0.5;
          final alpha = selected ? 1.0 : (1.0 - distance * 0.2).clamp(0.4, 1.0);
          // Right-offset arc: left pad = |d|×10+24; selected uses fixed pad.
          final startPad = selected
              ? ProcessModeDimens.wheelSelectedPadding
              : ProcessModeDimens.linearArcPad(distance);
          final label = Text(
            ProcessModeLabels.wheelLabel(type, l10n),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Colors.white.withOpacity(alpha),
              fontSize: selected
                  ? ProcessModeDimens.wheelSelectedTextSize
                  : ProcessModeDimens.wheelUnselectedTextSize,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              height: 1.1,
            ),
          );
          if (selected) {
            // Cap only the selected row before the gear scale; ellipsis if long.
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: startPad),
                child: SizedBox(
                  width: selectedTextMaxWidth,
                  child: Text(
                    ProcessModeLabels.wheelLabel(type, l10n),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white.withOpacity(alpha),
                      fontSize: ProcessModeDimens.wheelSelectedTextSize,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: startPad),
              child: SizedBox(
                width: math.max(0.0, labelBandWidth - startPad),
                child: label,
              ),
            ),
          );
        },
      ),
    );

    if (!showAccents) {
      // Laser Enable frost plate (lws-ui `model_wheel_view_content` 260×340).
      return Align(alignment: Alignment.centerLeft, child: wheel);
    }

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
                    alignEnd: true,
                    showFillTail: true,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: wheel,
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
    required this.alignEnd,
    required this.showFillTail,
  });

  final bool alignEnd;
  final bool showFillTail;

  @override
  Widget build(BuildContext context) {
    final solid = SizedBox(
      width: ProcessModeDimens.wheelAccentSolidWidth,
      height: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ProcessModeTokens.quickSelectionHighlightGradient,
        ),
      ),
    );
    final fill = Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ProcessModeTokens.quickSelectionHighlightGradient,
        ),
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
