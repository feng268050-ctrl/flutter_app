import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';

/// Flutter recreation of lws-ui's eight-card Custom Home editor.
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

  /// Outer panel edge inset (matches screen L/R margin).
  static const containerHorizontalInset = 24.0;

  /// Frost bright-edge stroke — same as Settings / Monitor (1.5).
  static const containerBorderWidth = 1.5;

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
        final haloHeight =
            (constraints.maxWidth * 223 / 1230).clamp(150.0, 223.0);
        final candidateGap = (haloHeight - 54 - 80 + 3).clamp(3.0, 120.0);
        final blurToken = Object.hashAll(_metrics.map((m) => m.index));
        // Halo-only target for card chrome; SettingsPage owns the full-screen
        // capture used by Save tip frost and background mist.
        return CyberBlurBackdropScope(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CyberBlurBackdropTarget(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF060720)),
                    Positioned(
                      left: CustomHomeTab.containerHorizontalInset,
                      right: CustomHomeTab.containerHorizontalInset,
                      top: CustomHomeTab.containerTopInset,
                      bottom: CustomHomeTab.containerBottomInset,
                      child: CyberOutlinedPanel(
                        clipBehavior: Clip.none,
                        outline: const CyberPanelOutline(
                          style: CyberPanelOutlineStyle.frostGradient,
                          width: CustomHomeTab.containerBorderWidth,
                          cornerRadius: 18,
                          gradientCenter:
                              CyberBorderGradientCenter.topLeftBottomRight,
                        ),
                        color: const Color(0x220D1234),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      top: CustomHomeTab.containerTopInset,
                      left: CustomHomeTab.containerHorizontalInset,
                      right: CustomHomeTab.containerHorizontalInset,
                      height: haloHeight,
                      child: Image.asset(
                        'assets/process/custom_home_halo.webp',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ],
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
                  blurSampleToken: blurToken,
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
          ),
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
    required this.blurSampleToken,
    required this.onReorder,
  });

  final List<CustomHomeMetric> metrics;
  final double candidateTop;
  final Object blurSampleToken;
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
                  blurSampleToken: widget.blurSampleToken,
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
                  child: Transform.scale(
                    scale: 1.05,
                    child: Opacity(
                      opacity: 0.8,
                      child: _CardFace(
                        metric: dragging,
                        active: widget.metrics.indexOf(dragging) < 4,
                        width: _dragSize.width,
                        blurSampleToken: widget.blurSampleToken,
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
    required this.blurSampleToken,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerEnd,
  });

  final CustomHomeMetric metric;
  final bool active;
  final double width;
  final bool dimmed;
  final Object blurSampleToken;
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
          opacity: dimmed ? 0.24 : 1,
          child: _CardFace(
            metric: metric,
            active: active,
            width: width,
            blurSampleToken: blurSampleToken,
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
    required this.blurSampleToken,
  });

  final CustomHomeMetric metric;
  final bool active;
  final double width;
  final Object blurSampleToken;

  static const _cardHeight = 80.0;
  static const _corner = 14.0;

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Center(
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

    return Container(
      key: ValueKey('custom-home-card-${metric.name}'),
      width: width,
      height: _cardHeight,
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (active)
            ClipRRect(
              borderRadius: BorderRadius.circular(_corner),
              child: CyberBackdropBlur(
                // Same frost fill as CyberModal / Zero Offset dialog.
                sampleMode: CyberBlurSampleMode.onChange,
                intensity: CyberBlurIntensity.high,
                blurTint: CyberBlurTint.dark,
                sampleToken: blurSampleToken,
                child: const SizedBox.expand(),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x9C11152D),
                borderRadius: BorderRadius.all(Radius.circular(_corner)),
              ),
            ),
          CustomPaint(foregroundPainter: _CardBorderPainter(active: active)),
          label,
        ],
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

/// Solid selection rim for the first four slots, dashed candidate rim for the
/// remaining cards, matching lws-ui's `item_car_border_true/false` semantics.
final class _CardBorderPainter extends CustomPainter {
  const _CardBorderPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    final paint = Paint()
      ..color = active ? const Color(0xD3E7EAFF) : const Color(0x778D98C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 1.4 : 1;
    if (active) {
      canvas.drawRRect(rect.deflate(0.7), paint);
      return;
    }
    final path = Path()..addRRect(rect.deflate(0.5));
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 8) {
        canvas.drawPath(
          metric.extractPath(
            offset,
            (offset + 4).clamp(0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardBorderPainter oldDelegate) =>
      oldDelegate.active != active;
}
