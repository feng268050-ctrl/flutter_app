import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';

/// Flutter recreation of lws-ui's eight-card Custom Home editor.
///
/// Keep only two pre-cut WebPs: [custom_back] for the upper plate halo, and
/// [item_car_border_true] for selected cards. The full-panel rim and candidate
/// card plates are drawn in code (thin grey stroke / translucent white fill).
/// Whole cards sit at alpha 0.8 so the panel plate shows through.
///
/// The first four cards are the Home dashboard selection; dragging a card
/// changes its order in memory, and Save persists the layout only (never
/// statistics). The Home page resolves each metric value from its aggregate.
class CustomHomeTab extends StatefulWidget {
  const CustomHomeTab({super.key, this.store});

  final CustomHomeLayoutStore? store;

  /// Gap between the painted panel bottom edge and the stack bottom.
  /// Matches [containerHorizontalInset] (screen L/R margin).
  static const containerBottomInset = 24.0;

  /// Gap between the tab strip and the large panel top.
  /// Matches [containerHorizontalInset] (screen L/R margin).
  static const containerTopInset = 24.0;

  /// Gap between Save Changes bottom and the painted panel bottom edge.
  static const saveToContainerBottom = 28.0;

  /// Outer panel edge inset (matches screen L/R margin / lws-ui 24dp).
  static const containerHorizontalInset = 24.0;

  /// lws-ui [fragment_dashboard] `custom_back` plate height.
  static const backPlateHeight = 240.0;

  /// Soft rim around the full editor panel (replaces `custom_back_border.webp`).
  static const panelBorderRadius = 18.0;
  static const panelBorderWidth = 1.25;
  static const panelBorderColor = Color(0xCEACACAC);

  static const _assetBack = 'assets/settings/custom_home/custom_back.webp';

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
    _metrics = List.of(_store.metrics);
  }

  Future<void> _save() async {
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

  void _move(CustomHomeMetric source, CustomHomeMetric target) {
    final from = _metrics.indexOf(source);
    final to = _metrics.indexOf(target);
    if (from < 0 || to < 0 || from == to) return;
    setState(() {
      _metrics.removeAt(from);
      _metrics.insert(to, source);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Space between the two card rows: plate height drives candidate gap
        // the same way the old halo height did.
        final candidateGap =
            (CustomHomeTab.backPlateHeight - 54 - 80 + 3).clamp(3.0, 120.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base plate — deep blue-purple under the upper edit region.
            Positioned(
              left: CustomHomeTab.containerHorizontalInset,
              right: CustomHomeTab.containerHorizontalInset,
              top: CustomHomeTab.containerTopInset,
              height: CustomHomeTab.backPlateHeight,
              child: Image.asset(
                CustomHomeTab._assetBack,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
            // Soft edge highlight around the full panel (drawn, not an asset).
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
              top: CustomHomeTab.containerTopInset + 54,
              left: 54,
              right: 54,
              height: candidateGap + 160,
              child: _MetricGrid(
                metrics: _metrics,
                candidateTop: candidateGap + 80,
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
      },
    );
  }
}

/// A two-row, four-column drag surface. Unlike generic [Draggable], this
/// starts its own floating card on pointer-down, so the feedback is immediate
/// and all neighboring cards can animate to their new slots as it moves.
class _MetricGrid extends StatefulWidget {
  const _MetricGrid({
    required this.metrics,
    required this.candidateTop,
    required this.onReorder,
  });

  final List<CustomHomeMetric> metrics;
  final double candidateTop;
  final void Function(CustomHomeMetric source, CustomHomeMetric target)
      onReorder;

  @override
  State<_MetricGrid> createState() => _MetricGridState();
}

class _MetricGridState extends State<_MetricGrid> {
  final _gridKey = GlobalKey();
  CustomHomeMetric? _draggingMetric;
  Offset _dragPosition = Offset.zero;
  Size _dragSize = Size.zero;

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

  CustomHomeMetric? _metricAt(Offset position, double cardWidth) {
    final gap = 12.0;
    final col = (position.dx / (cardWidth + gap)).floor();
    if (col < 0 || col >= 4) return null;
    final row = switch (position.dy) {
      final y when y >= 0 && y <= 80 => 0,
      final y when y >= widget.candidateTop && y <= widget.candidateTop + 80 =>
        1,
      _ => -1,
    };
    final index = row * 4 + col;
    if (row < 0 || index >= widget.metrics.length) return null;
    return widget.metrics[index];
  }

  void _endDrag(PointerEvent _) {
    if (_draggingMetric != null) {
      setState(() => _draggingMetric = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _gridKey,
      builder: (context, constraints) {
        const gap = 12.0;
        final cardWidth = (constraints.maxWidth - gap * 3) / 4;
        final dragging = _draggingMetric;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < widget.metrics.length; index++)
              AnimatedPositioned(
                key: ValueKey(
                    'custom-home-metric-${widget.metrics[index].name}'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: (index % 4) * (cardWidth + gap),
                top: index < 4 ? 0 : widget.candidateTop,
                width: cardWidth,
                height: 80,
                child: _MetricDragCard(
                  metric: widget.metrics[index],
                  active: index < 4,
                  width: cardWidth,
                  dimmed: widget.metrics[index] == dragging,
                  onPointerDown: (event, size) =>
                      _startDrag(widget.metrics[index], event, size),
                  onPointerMove: (event) => _updateDrag(event, cardWidth),
                  onPointerEnd: _endDrag,
                ),
              ),
            if (dragging != null)
              Positioned(
                left: _dragPosition.dx - _dragSize.width / 2,
                top: _dragPosition.dy - _dragSize.height / 2,
                width: _dragSize.width,
                height: _dragSize.height,
                child: IgnorePointer(
                  // lws-ui CardAdapter: scale 1.05 + alpha dip while dragging.
                  child: Transform.scale(
                    scale: 1.05,
                    child: _CardFace(
                      metric: dragging,
                      active: widget.metrics.indexOf(dragging) < 4,
                      width: _dragSize.width,
                      opacity: 0.64,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('custom-home-save'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 192,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF853E), Color(0xFFFF5C09)],
            ),
            border: Border.all(color: const Color(0xFFFFB070), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x66FF5C09), blurRadius: 12),
            ],
          ),
          child: const Center(
            child: Text(
              'Save Changes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricDragCard extends StatelessWidget {
  const _MetricDragCard({
    required this.metric,
    required this.active,
    required this.width,
    required this.dimmed,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final CustomHomeMetric metric;
  final bool active;
  final double width;
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
          // Slot left behind while the floating face is dragged.
          opacity: dimmed ? 0.24 : 1,
          child: _CardFace(
            metric: metric,
            active: active,
            width: width,
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.metric,
    required this.active,
    required this.width,
    this.opacity = _restAlpha,
  });

  final CustomHomeMetric metric;
  final bool active;
  final double width;

  /// Defaults to [_restAlpha]; drag feedback passes a slightly lower value.
  final double opacity;

  static const _cardHeight = 80.0;

  /// Resting card opacity — lws-ui `item_card` `android:alpha="0.8"`.
  static const _restAlpha = 0.8;

  /// Matches `item_car_border_true.webp` corner radius at 80dp card height.
  static const _cardRadius = 14.0;

  /// Candidate fill — `item_car_border_false.webp` center ≈ white @ alpha 10/255.
  static const _candidateFill = Color(0x0AFFFFFF);

  static const _assetActive =
      'assets/settings/custom_home/item_car_border_true.webp';

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        key: ValueKey('custom-home-card-${metric.name}'),
        width: width,
        height: _cardHeight,
        alignment: Alignment.center,
        decoration: active
            ? const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_assetActive),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              )
            : BoxDecoration(
                color: _candidateFill,
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          _label(metric),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            height: 1.05,
          ),
        ),
      ),
    );
  }

  static String _label(CustomHomeMetric metric) => switch (metric) {
        CustomHomeMetric.wireConsumption => 'Total Wire Consumption',
        CustomHomeMetric.laserOnDuration => 'Total Laser-on Time',
        CustomHomeMetric.jobRuntime => 'Job Runtime',
        CustomHomeMetric.weldRatio => 'Welding Ratio',
        CustomHomeMetric.cutRatio => 'Cutting Ratio',
        CustomHomeMetric.cleanRatio => 'Cleaning Ratio',
        CustomHomeMetric.weekOverWeekLaser => 'Laser Time vs Last Week',
        CustomHomeMetric.favoriteMaterial => 'Favorite Material',
      };
}
