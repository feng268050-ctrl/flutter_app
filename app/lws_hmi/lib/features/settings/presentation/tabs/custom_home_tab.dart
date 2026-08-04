import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Eight-card Custom Home editor.
///
/// The top pool holds unselected metrics and the lower halo holds up to four
/// Home slots. Changes remain local until Save Changes writes the combined
/// selected + candidate order to [CustomHomeLayoutStore].
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

  static const cardHeight = 112.0;
  static const gridTopInset = 26.0;
  static const gridHeight = 462.0;
  static const animationDuration = Duration(milliseconds: 400);
  static const animationCurve = Curves.fastOutSlowIn;

  @override
  State<CustomHomeTab> createState() => _CustomHomeTabState();
}

class _CustomHomeTabState extends State<CustomHomeTab> {
  late final CustomHomeLayoutStore _store =
      widget.store ?? CustomHomeLayoutStore();
  late List<CustomHomeMetric> _selected;
  late List<CustomHomeMetric> _candidates;

  CustomHomeMetric? _replacementCandidate;
  bool _inputLocked = false;
  bool _motionScaleDown = false;

  @override
  void initState() {
    super.initState();
    _store.warmRead();
    final order = List<CustomHomeMetric>.of(_store.metrics);
    _selected = order.take(4).toList();
    _candidates = order.skip(4).toList();
  }

  Future<void> _runMotion(VoidCallback update) async {
    if (_inputLocked) return;
    setState(() {
      _inputLocked = true;
      _motionScaleDown = true;
      update();
    });
    // Cards begin a touch smaller, then recover while their positions travel.
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (mounted) {
      setState(() => _motionScaleDown = false);
    }
    await Future<void>.delayed(
      CustomHomeTab.animationDuration - const Duration(milliseconds: 70),
    );
    if (mounted) {
      setState(() => _inputLocked = false);
    }
  }

  Future<void> _addCandidate(CustomHomeMetric metric) async {
    if (_inputLocked || !_candidates.contains(metric)) return;
    if (_selected.length < 4) {
      await _runMotion(() {
        _candidates.remove(metric);
        _selected.add(metric);
      });
      return;
    }
    // Full selection: picking a candidate enters replace mode only. Nothing is
    // persisted or swapped until the operator chooses a lower target card.
    if (_replacementCandidate == metric) {
      setState(() => _replacementCandidate = null);
      return;
    }
    setState(() => _replacementCandidate = metric);
    _showToast(
      AppLocalizations.of(context)?.customHomeSelectReplaceCard ??
          'Please select a card to replace',
    );
  }

  Future<void> _replaceAt(int selectedIndex) async {
    final incoming = _replacementCandidate;
    if (_inputLocked || incoming == null || selectedIndex < 0) return;
    final candidateIndex = _candidates.indexOf(incoming);
    if (candidateIndex < 0 || selectedIndex >= _selected.length) return;
    await _runMotion(() {
      final outgoing = _selected[selectedIndex];
      _selected[selectedIndex] = incoming;
      // Put the outgoing card into the incoming card's old slot. Stable keys
      // make both full-size cards travel at the same time rather than flash.
      _candidates[candidateIndex] = outgoing;
      _replacementCandidate = null;
    });
  }

  Future<void> _removeSelected(CustomHomeMetric metric) async {
    final index = _selected.indexOf(metric);
    if (_inputLocked || index < 0) return;
    await _runMotion(() {
      _selected.removeAt(index);
      _candidates.add(metric);
      _replacementCandidate = null;
    });
  }

  Future<void> _save() async {
    if (_inputLocked) return;
    if (_selected.length < 4) {
      _showToast(
        AppLocalizations.of(context)?.customHomeSelectFourCards ??
            'Please select 4 cards',
      );
      return;
    }
    try {
      await _store.saveOrder([..._selected, ..._candidates]);
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

  void _showToast(String message) => ProcessModeToast.show(context, message);

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
            replacementCandidate: _replacementCandidate,
            inputLocked: _inputLocked,
            motionScaleDown: _motionScaleDown,
            onAdd: _addCandidate,
            onReplaceAt: _replaceAt,
            onRemove: _removeSelected,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: CustomHomeTab.containerBottomInset +
              CustomHomeTab.saveToContainerBottom,
          child: Center(
            child: _SaveButton(onPressed: _inputLocked ? null : _save),
          ),
        ),
      ],
    );
  }
}

class _SelectionGrid extends StatelessWidget {
  const _SelectionGrid({
    required this.selected,
    required this.candidates,
    required this.replacementCandidate,
    required this.inputLocked,
    required this.motionScaleDown,
    required this.onAdd,
    required this.onReplaceAt,
    required this.onRemove,
  });

  final List<CustomHomeMetric> selected;
  final List<CustomHomeMetric> candidates;
  final CustomHomeMetric? replacementCandidate;
  final bool inputLocked;
  final bool motionScaleDown;
  final ValueChanged<CustomHomeMetric> onAdd;
  final ValueChanged<int> onReplaceAt;
  final ValueChanged<CustomHomeMetric> onRemove;

  static const _columns = 4;
  static const _columnGap = 14.0;
  static const _candidateCardTop = 34.0;
  static const _candidateRowGap = 16.0;
  static const _sectionLabelHeight = 24.0;
  static const _selectedLabelGap = 38.0;
  static const _selectedCardGap = 10.0;

  int get _candidateRows => (candidates.length + _columns - 1) ~/ _columns;

  double get _candidateRowPitch => CustomHomeTab.cardHeight + _candidateRowGap;

  double get _selectedLabelTop =>
      _candidateCardTop +
      _candidateRows * _candidateRowPitch +
      _selectedLabelGap;

  double get _selectedCardTop =>
      _selectedLabelTop + _sectionLabelHeight + _selectedCardGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - _columnGap * 3) / _columns;
        final selectedPulse = replacementCandidate != null;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              left: 0,
              top: 0,
              child: Text(
                'CANDIDATES',
                style: TextStyle(
                  color: Color(0xFFD4D9E5),
                  fontSize: AppTypography.supportingSize,
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
                  const Text(
                    'SELECTED ON HOME',
                    style: TextStyle(
                      color: Color(0xFFD4D9E5),
                      fontSize: AppTypography.supportingSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Selected ${selected.length}/4',
                    style: TextStyle(
                      color: selected.length == 4
                          ? const Color(0xFFBBD1FF)
                          : const Color(0xFFD4D9E5),
                      fontSize: AppTypography.supportingSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < candidates.length; index++)
              _positionedCard(
                metric: candidates[index],
                selected: false,
                position: _candidatePosition(index, cardWidth),
                width: cardWidth,
                index: index,
                pulse: false,
              ),
            for (var index = 0; index < selected.length; index++)
              _positionedCard(
                metric: selected[index],
                selected: true,
                position: Offset(
                  index * (cardWidth + _columnGap),
                  _selectedCardTop,
                ),
                width: cardWidth,
                index: index,
                pulse: selectedPulse,
              ),
          ],
        );
      },
    );
  }

  Offset _candidatePosition(int index, double cardWidth) => Offset(
        (index % _columns) * (cardWidth + _columnGap),
        _candidateCardTop + (index ~/ _columns) * _candidateRowPitch,
      );

  Widget _positionedCard({
    required CustomHomeMetric metric,
    required bool selected,
    required Offset position,
    required double width,
    required int index,
    required bool pulse,
  }) {
    return AnimatedPositioned(
      key: ValueKey('custom-home-motion-${metric.name}'),
      duration: CustomHomeTab.animationDuration,
      curve: CustomHomeTab.animationCurve,
      left: position.dx,
      top: position.dy,
      width: width,
      height: CustomHomeTab.cardHeight,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        scale: motionScaleDown ? 0.96 : 1,
        child: _MetricSelectionCard(
          metric: metric,
          selected: selected,
          slot: selected ? index + 1 : null,
          replacementActive: selected && pulse,
          replacementCandidate: replacementCandidate == metric,
          inputLocked: inputLocked,
          onAdd: selected ? null : () => onAdd(metric),
          onSelectReplacement: selected ? () => onReplaceAt(index) : null,
          onRemove: selected ? () => onRemove(metric) : null,
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
    return SizedBox(
      width: 340,
      child: CyberButton(
        key: const ValueKey('custom-home-save'),
        size: CyberButtonSize.small,
        variant: CyberButtonVariant.primary,
        shape: CyberButtonShape.rounded,
        stretch: true,
        onPressed: onPressed,
        child: Text(AppLocalizations.of(context)!.saveChanges),
      ),
    );
  }
}

class _MetricSelectionCard extends StatelessWidget {
  const _MetricSelectionCard({
    required this.metric,
    required this.selected,
    required this.slot,
    required this.replacementActive,
    required this.replacementCandidate,
    required this.inputLocked,
    required this.onAdd,
    required this.onSelectReplacement,
    required this.onRemove,
  });

  final CustomHomeMetric metric;
  final bool selected;
  final int? slot;
  final bool replacementActive;
  final bool replacementCandidate;
  final bool inputLocked;
  final VoidCallback? onAdd;
  final VoidCallback? onSelectReplacement;
  final VoidCallback? onRemove;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = !inputLocked;
    final candidateDisabled =
        (!selected && onAdd == null) || (selected && replacementActive);
    final pendingReplacement = !selected && replacementCandidate;
    final cardContent = Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 18, 30, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _icon(metric),
                  color: selected
                      ? const Color(0xFFC6D6F4)
                      : const Color(0xFFE8EEF9),
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  _label(l10n, metric),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFF1F4FB),
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: 10,
            left: 10,
            child: _SlotBadge(slot: slot!),
          ),
        if (pendingReplacement)
          Positioned(
            top: 13,
            left: 14,
            child: Text(
              AppLocalizations.of(context)?.customHomeReplacementSelected ??
                  'Selected',
              style: const TextStyle(
                color: Color(0xFFFFD7B9),
                fontSize: AppTypography.microSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: _CardCornerButton(
            selected: selected,
            pendingReplacement: pendingReplacement,
            enabled: enabled && !candidateDisabled,
            metric: metric,
            onPressed: selected ? onRemove : onAdd,
          ),
        ),
      ],
    );
    final body = AnimatedContainer(
      key: ValueKey('custom-home-card-${metric.name}'),
      duration: CustomHomeTab.animationDuration,
      curve: CustomHomeTab.animationCurve,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        gradient: selected
            ? null
            : pendingReplacement
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF05C331F), Color(0xED211512)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x5CFFFFFF), Color(0x3EFFF8F6)],
                  ),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : pendingReplacement
                  ? const Color(0xFFFFA15F)
                  : const Color(0x99FFFFFF),
          width: selected
              ? 0
              : pendingReplacement
                  ? 1.4
                  : 1,
        ),
        boxShadow: pendingReplacement
            ? const [
                BoxShadow(
                  color: Color(0x9CFF7A35),
                  blurRadius: 13,
                  spreadRadius: -2,
                  offset: Offset(2, 4),
                ),
              ]
            : const [],
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

    final onCardTap =
        selected ? (replacementActive ? onSelectReplacement : null) : onAdd;
    final interactive = onCardTap != null
        ? InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: enabled ? onCardTap : null,
            child: body,
          )
        : body;
    return _ReplacementPulse(
        active: selected && replacementActive, child: interactive);
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
        CustomHomeMetric.wireConsumption => l10n.totalWireConsumption,
        CustomHomeMetric.laserOnDuration => l10n.totalLaserOnTime,
        CustomHomeMetric.jobRuntime => l10n.jobRuntime,
        CustomHomeMetric.weldRatio => l10n.weldingProportionText,
        CustomHomeMetric.cutRatio => l10n.cuttingProportionText,
        CustomHomeMetric.cleanRatio => l10n.washProportionText,
        CustomHomeMetric.weekOverWeekLaser => l10n.laserTimeVsLastWeek,
        CustomHomeMetric.favoriteMaterial => l10n.favoriteMaterial,
      };
}

class _CardCornerButton extends StatelessWidget {
  const _CardCornerButton({
    required this.selected,
    required this.pendingReplacement,
    required this.enabled,
    required this.metric,
    required this.onPressed,
  });

  final bool selected;
  final bool pendingReplacement;
  final bool enabled;
  final CustomHomeMetric metric;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final checked = selected || pendingReplacement;
    return Semantics(
      button: true,
      label: checked ? 'Selected ${metric.name}' : 'Add ${metric.name}',
      child: InkResponse(
        key: ValueKey(
          selected
              ? 'custom-home-remove-${metric.name}'
              : 'custom-home-add-${metric.name}',
        ),
        radius: 22,
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked
                ? CyberColors.buttonPrimaryAccent
                : const Color(0x1AFFFFFF),
            border: Border.all(
              color: checked ? const Color(0xFFFFB07B) : Colors.white70,
            ),
          ),
          child: Icon(
            checked ? Icons.check_rounded : Icons.add_rounded,
            color: Colors.white,
            size: 23,
          ),
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppTypography.supportingSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReplacementPulse extends StatefulWidget {
  const _ReplacementPulse({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_ReplacementPulse> createState() => _ReplacementPulseState();
}

class _ReplacementPulseState extends State<_ReplacementPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ReplacementPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_MetricSelectionCard._radius),
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x30FF8A4D),
                      const Color(0xA8FF8A4D),
                      _controller.value,
                    )!,
                    blurRadius: 8 + _controller.value * 8,
                    spreadRadius: -1 + _controller.value,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
    );
  }
}
