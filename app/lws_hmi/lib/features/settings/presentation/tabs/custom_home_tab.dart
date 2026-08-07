import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';

/// Eight-card Custom Home editor.
///
/// Candidates sit above the four Home slots. Drag a card onto another to
/// reorder (lws-ui slide swap); Save writes the combined order to
/// [CustomHomeLayoutStore]. Card chrome matches the frosted selection UI.
class CustomHomeTab extends StatefulWidget {
  const CustomHomeTab({super.key, this.store});

  final CustomHomeLayoutStore? store;

  static const containerBottomInset = 24.0;
  static const containerTopInset = 24.0;
  static const saveToContainerBottom = 28.0;
  static const containerHorizontalInset = 24.0;
  static const panelBorderRadius = 18.0;
  static const panelBorderWidth = 1.25;
  static const panelBorderColor = Color(0xCEACACAC);

  static const cardHeight = 128.0;
  static const cardIconSize = 44.0;
  static const gridTopInset = 26.0;
  static const gridHeight = 494.0;
  static const animationDuration = Duration(milliseconds: 400);
  static const animationCurve = Curves.fastOutSlowIn;

  @override
  State<CustomHomeTab> createState() => _CustomHomeTabState();
}

class _CustomHomeTabState extends State<CustomHomeTab> {
  late final CustomHomeLayoutStore _store =
      widget.store ?? CustomHomeLayoutStore();
  late List<CustomHomeMetric> _metrics;

  @override
  void initState() {
    super.initState();
    _store.warmRead();
    _metrics = List<CustomHomeMetric>.of(_store.metrics);
  }

  List<CustomHomeMetric> get _selected => _metrics.take(4).toList();
  List<CustomHomeMetric> get _candidates => _metrics.skip(4).toList();

  void _move(CustomHomeMetric source, CustomHomeMetric target) {
    final from = _metrics.indexOf(source);
    final to = _metrics.indexOf(target);
    if (from < 0 || to < 0 || from == to) return;
    setState(() {
      _metrics.removeAt(from);
      _metrics.insert(to, source);
    });
  }

  Future<void> _save() async {
    if (_selected.length < 4) {
      ProcessModeToast.show(
        context,
        AppLocalizations.of(context)?.customHomeSelectFourCards ??
            'Please select 4 cards',
      );
      return;
    }
    try {
      await _store.saveOrder(_metrics);
    } catch (_) {
      if (mounted) {
        await showCustomHomeSaveFailureDialog(context);
      }
      return;
    }
    if (mounted) {
      await showCustomHomeSaveSuccessDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: CustomHomeTab.containerHorizontalInset,
          right: CustomHomeTab.containerHorizontalInset,
          top: CustomHomeTab.containerTopInset,
          bottom: CustomHomeTab.containerBottomInset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  CustomHomeTab.panelBorderRadius,
                ),
                border: Border.all(
                  color: CustomHomeTab.panelBorderColor,
                  width: CustomHomeTab.panelBorderWidth,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: CustomHomeTab.containerTopInset + CustomHomeTab.gridTopInset,
          left: 54,
          right: 54,
          height: CustomHomeTab.gridHeight,
          child: _SelectionGrid(
            selected: _selected,
            candidates: _candidates,
            onReorder: _move,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: CustomHomeTab.containerBottomInset +
              CustomHomeTab.saveToContainerBottom,
          child: Center(child: _SaveButton(onPressed: _save)),
        ),
      ],
    );
  }
}

/// Candidates above / selected below. Pointer drag swaps order like lws-ui.
class _SelectionGrid extends StatefulWidget {
  const _SelectionGrid({
    required this.selected,
    required this.candidates,
    required this.onReorder,
  });

  final List<CustomHomeMetric> selected;
  final List<CustomHomeMetric> candidates;
  final void Function(CustomHomeMetric source, CustomHomeMetric target)
      onReorder;

  @override
  State<_SelectionGrid> createState() => _SelectionGridState();
}

class _SelectionGridState extends State<_SelectionGrid> {
  static const _columns = 4;
  static const _columnGap = 14.0;
  static const _candidateCardTop = 34.0;
  static const _candidateRowGap = 16.0;
  static const _sectionLabelHeight = 24.0;
  static const _selectedLabelGap = 38.0;
  static const _selectedCardGap = 10.0;

  final _gridKey = GlobalKey();
  CustomHomeMetric? _draggingMetric;
  Offset _dragPosition = Offset.zero;
  Size _dragSize = Size.zero;

  int get _candidateRows =>
      (widget.candidates.length + _columns - 1) ~/ _columns;

  double get _candidateRowPitch => CustomHomeTab.cardHeight + _candidateRowGap;

  double get _selectedLabelTop =>
      _candidateCardTop +
      _candidateRows * _candidateRowPitch +
      _selectedLabelGap;

  double get _selectedCardTop =>
      _selectedLabelTop + _sectionLabelHeight + _selectedCardGap;

  void _startDrag(CustomHomeMetric metric, PointerDownEvent event, Size size) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _draggingMetric = metric;
      _dragPosition = box.globalToLocal(event.position);
      _dragSize = size;
    });
  }

  void _updateDrag(PointerMoveEvent event, double cardWidth) {
    final metric = _draggingMetric;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (metric == null || box == null) return;
    final position = box.globalToLocal(event.position);
    final target = _metricAt(position, cardWidth);
    if (target != null && target != metric) {
      widget.onReorder(metric, target);
    }
    setState(() => _dragPosition = position);
  }

  void _endDrag(PointerEvent _) {
    if (_draggingMetric != null) {
      setState(() => _draggingMetric = null);
    }
  }

  CustomHomeMetric? _metricAt(Offset position, double cardWidth) {
    final col = (position.dx / (cardWidth + _columnGap)).floor();
    if (col < 0 || col >= _columns) return null;

    for (var row = 0; row < _candidateRows; row++) {
      final top = _candidateCardTop + row * _candidateRowPitch;
      if (position.dy >= top &&
          position.dy <= top + CustomHomeTab.cardHeight) {
        final index = row * _columns + col;
        if (index >= 0 && index < widget.candidates.length) {
          return widget.candidates[index];
        }
        return null;
      }
    }

    if (position.dy >= _selectedCardTop &&
        position.dy <= _selectedCardTop + CustomHomeTab.cardHeight) {
      if (col < widget.selected.length) {
        return widget.selected[col];
      }
    }
    return null;
  }

  Offset _candidatePosition(int index, double cardWidth) => Offset(
        (index % _columns) * (cardWidth + _columnGap),
        _candidateCardTop + (index ~/ _columns) * _candidateRowPitch,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _gridKey,
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - _columnGap * 3) / _columns;
        final dragging = _draggingMetric;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Text(
                'CANDIDATES',
                style: context.hmiTypography.supporting.copyWith(
                  color: const Color(0xFFD4D9E5),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: _selectedLabelTop,
              right: 0,
              height: _sectionLabelHeight,
              child: Row(
                children: [
                  Text(
                    'SELECTED ON HOME',
                    style: context.hmiTypography.supporting.copyWith(
                      color: const Color(0xFFD4D9E5),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Selected ${widget.selected.length}/4',
                    style: context.hmiTypography.supporting.copyWith(
                      color: widget.selected.length == 4
                          ? const Color(0xFFBBD1FF)
                          : const Color(0xFFD4D9E5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < widget.candidates.length; index++)
              _positionedCard(
                metric: widget.candidates[index],
                selected: false,
                position: _candidatePosition(index, cardWidth),
                width: cardWidth,
                slot: null,
                dimmed: widget.candidates[index] == dragging,
                cardWidth: cardWidth,
              ),
            for (var index = 0; index < widget.selected.length; index++)
              _positionedCard(
                metric: widget.selected[index],
                selected: true,
                position: Offset(
                  index * (cardWidth + _columnGap),
                  _selectedCardTop,
                ),
                width: cardWidth,
                slot: index + 1,
                dimmed: widget.selected[index] == dragging,
                cardWidth: cardWidth,
              ),
            if (dragging != null)
              Positioned(
                left: _dragPosition.dx - _dragSize.width / 2,
                top: _dragPosition.dy - _dragSize.height / 2,
                width: _dragSize.width,
                height: _dragSize.height,
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: 1.05,
                    child: Opacity(
                      opacity: 0.88,
                      child: _MetricSelectionCard(
                        metric: dragging,
                        selected: widget.selected.contains(dragging),
                        slot: widget.selected.contains(dragging)
                            ? widget.selected.indexOf(dragging) + 1
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _positionedCard({
    required CustomHomeMetric metric,
    required bool selected,
    required Offset position,
    required double width,
    required int? slot,
    required bool dimmed,
    required double cardWidth,
  }) {
    return AnimatedPositioned(
      key: ValueKey('custom-home-motion-${metric.name}'),
      duration: CustomHomeTab.animationDuration,
      curve: CustomHomeTab.animationCurve,
      left: position.dx,
      top: position.dy,
      width: width,
      height: CustomHomeTab.cardHeight,
      child: _MetricDragShell(
        dimmed: dimmed,
        onPointerDown: (event, size) => _startDrag(metric, event, size),
        onPointerMove: (event) => _updateDrag(event, cardWidth),
        onPointerEnd: _endDrag,
        child: _MetricSelectionCard(
          metric: metric,
          selected: selected,
          slot: slot,
        ),
      ),
    );
  }
}

class _MetricDragShell extends StatelessWidget {
  const _MetricDragShell({
    required this.child,
    required this.dimmed,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final Widget child;
  final bool dimmed;
  final void Function(PointerDownEvent event, Size size) onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerEvent> onPointerEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => onPointerDown(
          event,
          Size(constraints.maxWidth, constraints.maxHeight),
        ),
        onPointerMove: onPointerMove,
        onPointerUp: onPointerEnd,
        onPointerCancel: onPointerEnd,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: dimmed ? 0.28 : 1,
          child: child,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return HmiButton(
      key: const ValueKey('custom-home-save'),
      label: AppLocalizations.of(context)!.saveChanges,
      size: HmiButtonSize.large,
      widthPolicy: HmiButtonWidthPolicy.fixed,
      width: 480,
      variant: CyberButtonVariant.primary,
      shape: CyberButtonShape.rounded,
      onPressed: onPressed,
    );
  }
}

class _MetricSelectionCard extends StatelessWidget {
  const _MetricSelectionCard({
    required this.metric,
    required this.selected,
    required this.slot,
  });

  final CustomHomeMetric metric;
  final bool selected;
  final int? slot;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardContent = Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icon(metric),
                  color: selected
                      ? const Color(0xFFC6D6F4)
                      : const Color(0xFFE8EEF9),
                  size: CustomHomeTab.cardIconSize,
                ),
                const SizedBox(height: 6),
                WordBoundaryLabel(
                  text: _label(l10n, metric),
                  textAlign: TextAlign.center,
                  style: context.hmiTypography.metricLabel.copyWith(
                    color: selected ? Colors.white : const Color(0xFFF1F4FB),
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected && slot != null)
          Positioned(
            top: 10,
            left: 10,
            child: _SlotBadge(slot: slot!),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: _CardCornerButton(
            selected: selected,
            metric: metric,
          ),
        ),
      ],
    );
    return AnimatedContainer(
      key: ValueKey('custom-home-card-${metric.name}'),
      duration: CustomHomeTab.animationDuration,
      curve: CustomHomeTab.animationCurve,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: selected
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x5CFFFFFF), Color(0x3EFFF8F6)],
              ),
        border: Border.all(
          color: selected ? Colors.transparent : const Color(0x99FFFFFF),
          width: selected ? 0 : 1,
        ),
      ),
      child: selected
          ? CyberCard(
              sampleMode: CyberBlurSampleMode.realtime,
              intensity: CyberBlurIntensity.low,
              blurTint: CyberBlurTint.dark,
              borderRadius: BorderRadius.circular(_radius),
              borderColor: Colors.transparent,
              borderWidth: 0,
              child: cardContent,
            )
          : cardContent,
    );
  }

  static IconData _icon(CustomHomeMetric metric) => switch (metric) {
        CustomHomeMetric.wireConsumption => Icons.all_inclusive_rounded,
        CustomHomeMetric.laserOnDuration => Icons.schedule_rounded,
        CustomHomeMetric.jobRuntime => Icons.timer_outlined,
        CustomHomeMetric.weldRatio => Icons.pie_chart_rounded,
        CustomHomeMetric.cutRatio => Icons.bar_chart_rounded,
        CustomHomeMetric.cleanRatio => Icons.auto_awesome_rounded,
        CustomHomeMetric.weekOverWeekLaser => Icons.show_chart_rounded,
        CustomHomeMetric.favoriteMaterial => Icons.inventory_2_outlined,
      };

  static String _label(AppLocalizations l10n, CustomHomeMetric metric) =>
      switch (metric) {
        // Titles match lws-ui `HomeLayoutUtils.typeToTitle`.
        CustomHomeMetric.wireConsumption => l10n.warnInfoWeldingConsumables,
        CustomHomeMetric.laserOnDuration => l10n.warnInfoLightTime,
        CustomHomeMetric.jobRuntime => l10n.warnInfoLastWork,
        CustomHomeMetric.weldRatio => l10n.weldingProportionText,
        CustomHomeMetric.cutRatio => l10n.cuttingProportionText,
        CustomHomeMetric.cleanRatio => l10n.washProportionText,
        CustomHomeMetric.weekOverWeekLaser => l10n.warnInfoLightTimeInfo,
        CustomHomeMetric.favoriteMaterial => l10n.warnInfoWeldingConsumablesInfo,
      };
}

class _CardCornerButton extends StatelessWidget {
  const _CardCornerButton({
    required this.selected,
    required this.metric,
  });

  final bool selected;
  final CustomHomeMetric metric;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: selected ? 'Selected ${metric.name}' : 'Candidate ${metric.name}',
      child: Container(
        key: ValueKey(
          selected
              ? 'custom-home-selected-${metric.name}'
              : 'custom-home-candidate-${metric.name}',
        ),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? CyberColors.buttonPrimaryAccent
              : const Color(0x1AFFFFFF),
          border: Border.all(
            color: selected ? const Color(0xFFFFB07B) : Colors.white70,
          ),
        ),
        child: Icon(
          selected ? Icons.check_rounded : Icons.add_rounded,
          color: Colors.white,
          size: 23,
        ),
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xB600091A),
        border: Border.all(color: const Color(0xFFE2ECFF)),
      ),
      child: Text(
        '$slot',
        style: context.hmiTypography.supporting.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
