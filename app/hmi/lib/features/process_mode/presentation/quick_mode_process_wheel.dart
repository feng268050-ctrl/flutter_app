import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';

/// Quick Mode process-type offset wheel (lws-ui `wheel_view` + accent bands).
///
/// U2 skeleton: selection + chrome only; does not read the process library.
final class QuickModeProcessWheel extends StatefulWidget {
  const QuickModeProcessWheel({
    super.key,
    required this.processType,
    required this.onChanged,
  });

  final ProcessType processType;
  final ValueChanged<ProcessType> onChanged;

  @override
  State<QuickModeProcessWheel> createState() => _QuickModeProcessWheelState();
}

final class _QuickModeProcessWheelState extends State<QuickModeProcessWheel> {
  late final FixedExtentScrollController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = QuickProcessWheelItems.types.indexOf(widget.processType);
    if (_index < 0) {
      _index = 0;
    }
    _controller = FixedExtentScrollController(initialItem: _index);
  }

  @override
  void didUpdateWidget(covariant QuickModeProcessWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.processType == widget.processType) {
      return;
    }
    final next = QuickProcessWheelItems.types.indexOf(widget.processType);
    if (next < 0 || next == _index) {
      return;
    }
    _index = next;
    if (_controller.hasClients) {
      _controller.jumpToItem(next);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= QuickProcessWheelItems.types.length) {
      return;
    }
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
    widget.onChanged(QuickProcessWheelItems.types[index]);
  }

  @override
  Widget build(BuildContext context) {
    final accent = ProcessModeTokens.accentFor(widget.processType);
    final hideSideAccent = widget.processType == ProcessType.cncCutting;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: ProcessModeDimens.wheelAccentBandWidth,
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
                width: ProcessModeDimens.wheelWidth,
                height: ProcessModeDimens.wheelHeight,
                child: KeyedSubtree(
                  key: const ValueKey('quick-mode-process-wheel'),
                  child: ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: ProcessModeDimens.wheelItemHeight,
                    diameterRatio: 5,
                    perspective: 0.002,
                    offAxisFraction: -0.35,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: _select,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: QuickProcessWheelItems.types.length,
                      builder: (context, index) {
                        final type = QuickProcessWheelItems.types[index];
                        final selected = index == _index;
                        final distance = (index - _index).abs();
                        final alpha = selected
                            ? 1.0
                            : (1.0 - distance * 0.2).clamp(0.4, 1.0);
                        final startPad = ProcessModeDimens
                                .wheelSelectedPadding +
                            distance * ProcessModeDimens.wheelDistancePadding;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding:
                                EdgeInsetsDirectional.only(start: startPad),
                            child: Text(
                              ProcessModeLabels.wheelLabel(type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(alpha),
                                fontSize: selected
                                    ? ProcessModeDimens.wheelSelectedTextSize
                                    : ProcessModeDimens.wheelUnselectedTextSize,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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
