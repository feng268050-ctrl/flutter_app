import 'dart:async';
import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/live_machine_status_dialog.dart';

/// Center laser instrument cluster — Flutter port of lws-ui `LaserProgress`.
///
/// Layers: outer/inner progress rings + standalone thin highlight arc + decorative mipmaps
/// + center gas-pressure panel. Ring progress animates with [laserOn] (not
/// pressure); opacity follows [laserEnable]; center digits follow [gasPressureKpa].
final class QuickModeLaserDashboard extends StatefulWidget {
  const QuickModeLaserDashboard({
    super.key,
    required this.processType,
    required this.gasPressureKpa,
    required this.laserEnable,
    required this.laserOn,
    this.onMoreStatus,
  });

  final ProcessType processType;
  final double gasPressureKpa;

  /// `control.laser_enable` — rings dim to 50% when false (lws-ui `laser_status`).
  final bool laserEnable;

  /// `machine.laser_on` — drives 0↔100 progress animation (lws-ui DeviceStatus).
  final bool laserOn;

  final VoidCallback? onMoreStatus;

  /// Match Android `LaserProgress` up/down animator durations.
  static const Duration upDuration = Duration(milliseconds: 5000);
  static const Duration downDuration = Duration(milliseconds: 3000);

  @override
  State<QuickModeLaserDashboard> createState() =>
      _QuickModeLaserDashboardState();
}

final class _QuickModeLaserDashboardState extends State<QuickModeLaserDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _tween;
  double _progress = 0;
  bool? _lastLaserOn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addListener(() {
        final anim = _tween;
        if (anim == null) {
          return;
        }
        setState(() => _progress = anim.value);
      });
    _lastLaserOn = widget.laserOn;
    if (widget.laserOn) {
      _animateTo(100, QuickModeLaserDashboard.upDuration);
    }
  }

  @override
  void didUpdateWidget(covariant QuickModeLaserDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.laserOn == _lastLaserOn) {
      return;
    }
    _lastLaserOn = widget.laserOn;
    if (widget.laserOn) {
      _animateTo(100, QuickModeLaserDashboard.upDuration);
    } else {
      _animateTo(0, QuickModeLaserDashboard.downDuration);
    }
  }

  void _animateTo(double target, Duration fullDuration) {
    final from = _progress;
    if ((from - target).abs() < 0.01) {
      _controller.stop();
      setState(() => _progress = target);
      return;
    }
    // Scale duration by remaining distance (Android restarts from current).
    final span = (target - from).abs() / 100.0;
    final scaled = Duration(
      milliseconds: (fullDuration.inMilliseconds * span)
          .round()
          .clamp(1, fullDuration.inMilliseconds),
    );
    _controller
      ..stop()
      ..duration = scaled
      ..value = 0;
    _tween = Tween<double>(begin: from, end: target).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _LaserDashboardPalette.forType(widget.processType);
    final metrics =
        _LaserDashboardMetrics.fromViewport(MediaQuery.sizeOf(context));
    final ringAlpha = widget.laserEnable ? 1.0 : 0.5;
    final pressureText = widget.gasPressureKpa.round().toString();

    return SizedBox(
      key: const ValueKey('quick-mode-laser-dashboard'),
      width: metrics.size,
      height: metrics.height,
      child: Stack(
        alignment: Alignment.center,
        // The lws-ui RelativeLayout wraps the 541×573.5dp border at y=30,
        // making the component 570×603.5dp. Keep that overflow rather than
        // cropping it at 570.
        clipBehavior: Clip.hardEdge,
        children: [
          Align(
            alignment: Alignment.center,
            child: IgnorePointer(
              child: Opacity(
                opacity: ringAlpha,
                child: CustomPaint(
                  size: Size.square(metrics.size),
                  painter: _LaserProgressRingsPainter(
                    progress: _progress / 100.0,
                    palette: palette,
                    metrics: metrics,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: metrics.splitTopLeft,
            top: 0,
            child: IgnorePointer(
              child: Image.asset(
                ProcessModeAssets.circleSplitBorderTop,
                width: metrics.splitTopWidth,
                height: metrics.splitTopHeight,
                fit: BoxFit.contain,
                opacity: const AlwaysStoppedAnimation(0.8),
              ),
            ),
          ),
          Positioned(
            left: metrics.splitLeft,
            top: metrics.splitTop,
            child: IgnorePointer(
              child: Image.asset(
                ProcessModeAssets.circleSplitBorder,
                width: metrics.splitWidth,
                height: metrics.splitHeight,
                fit: BoxFit.contain,
                opacity: const AlwaysStoppedAnimation(0.3),
              ),
            ),
          ),
          Positioned(
            left: metrics.borderLeft,
            top: metrics.borderTop,
            child: IgnorePointer(
              child: Image.asset(
                ProcessModeAssets.circleBorder,
                width: metrics.borderWidth,
                height: metrics.borderHeight,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Digit on circle center; title at original Column slot; kPa +20dp;
          // More Status under the unit with original intrinsic size.
          SizedBox(
            width: metrics.centerSize,
            height: metrics.centerSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                image: DecorationImage(
                  image: AssetImage(palette.pressureBg),
                  fit: BoxFit.cover,
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Text(
                      pressureText,
                      key: const ValueKey('quick-mode-gas-pressure'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: metrics.valueSize,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                  ),
                  Positioned(
                    top: metrics.contentTop,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Text(
                        'Gas Pressure',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xCCFFFFFF),
                          fontSize: metrics.titleSize,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        metrics.valueSize / 2 +
                            metrics.contentGap +
                            metrics.unitSize / 2 +
                            20 * metrics.scale,
                      ),
                      child: Text(
                        'kPa',
                        style: TextStyle(
                          color: const Color(0x66FFFFFF),
                          fontSize: metrics.unitSize,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: metrics.centerSize / 2 +
                        metrics.valueSize / 2 +
                        metrics.contentGap +
                        metrics.unitSize +
                        20 * metrics.scale +
                        metrics.buttonGap,
                    left: 0,
                    right: 0,
                    child: Center(
                      // lws-ui `more_monitor_btn`: FrostButton + bright rim.
                      // Width kept under the circle chord at this Y so the 亮边
                      // is not clipped by the circular pressure face.
                      child: SizedBox(
                        width: 250 * metrics.scale,
                        child: CyberButton(
                          key: const ValueKey('quick-mode-more-status'),
                          size: CyberButtonSize.small,
                          variant: CyberButtonVariant.standard,
                          shape: CyberButtonShape.rounded,
                          stretch: true,
                          // 1.5px frost rim + diagonal HL (engineer Reset/Save).
                          strokeWidth: 1.5,
                          borderGradientCenter:
                              CyberBorderGradientCenter.topBottom,
                          borderGradientColors: const [
                            Color(0xE6FFFFFF),
                            Color(0xAA86868C),
                            Color(0x66000000),
                          ],
                          // Small face height only; width stays 250×scale.
                          height: CyberDimens.actionButtonSmallHeight,
                          onPressed: widget.onMoreStatus ??
                              () => unawaited(
                                    showLiveMachineStatusDialog(context),
                                  ),
                          child: SizedBox(
                            height: CyberDimens.actionButtonSmallHeight,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Center(
                                  child: Text(
                                    'More Status',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: metrics.buttonTextSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  // Trailing chevron: right inset = top inset.
                                  right: (CyberDimens.actionButtonSmallHeight -
                                          metrics.buttonIconSize) /
                                      2,
                                  top: (CyberDimens.actionButtonSmallHeight -
                                          metrics.buttonIconSize) /
                                      2,
                                  child: Icon(
                                    Icons.chevron_right,
                                    size: metrics.buttonIconSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode-dependent track / progress colors from lws-ui `colors.xml` + LaserProgress.
final class _LaserDashboardPalette {
  const _LaserDashboardPalette({
    required this.outerTrack,
    required this.innerTrack,
    required this.lineProgress,
    required this.outerProgress,
    required this.innerProgress,
    required this.pressureBg,
  });

  final Color outerTrack;
  final Color innerTrack;
  final Color lineProgress;
  final List<Color> outerProgress;
  final List<Color> innerProgress;
  final String pressureBg;

  static _LaserDashboardPalette forType(ProcessType type) {
    if (type.isCleaning) {
      return const _LaserDashboardPalette(
        outerTrack: Color(0xFF37F3D2),
        innerTrack: Color(0xFF19C0A4),
        lineProgress: Color(0xFF19C7AA),
        outerProgress: [
          Color(0xFF37EFD3),
          Color(0xFF3CD2E4),
          Color(0xFF3CD2E4),
          Color(0xFF41A2FC),
        ],
        innerProgress: [
          Color(0xFF196055),
          Color(0xFF3CD2E4),
          Color(0xFF3CD2E4),
          Color(0xFF41A2FC),
        ],
        pressureBg: ProcessModeAssets.pressureMonitoringGreen,
      );
    }
    if (type == ProcessType.handCutting || type == ProcessType.cncCutting) {
      return const _LaserDashboardPalette(
        outerTrack: Color(0xFF0151F4),
        innerTrack: Color(0xFF1C35BD),
        lineProgress: Color(0xFF1E38C9),
        outerProgress: [
          Color(0xFF5552FF),
          Color(0xFF7858FB),
          Color(0xFF7858FB),
          Color(0xFFB161F4),
        ],
        innerProgress: [
          Color(0xFF5552FF),
          Color(0xFF7858FB),
          Color(0xFF7858FB),
          Color(0xFFB161F4),
        ],
        pressureBg: ProcessModeAssets.pressureMonitoringBlue,
      );
    }
    return const _LaserDashboardPalette(
      outerTrack: Color(0xFFF46E01),
      innerTrack: Color(0xFFB35517),
      lineProgress: Color(0xFFB65718),
      outerProgress: [
        Color(0xFFB75717),
        Color(0xFFFFB016),
        Color(0xFFFFB016),
        Color(0xFFFFBD18),
      ],
      innerProgress: [
        Color(0xFF42260D),
        Color(0xFFDD7315),
        Color(0xFFDD7315),
        Color(0xFFFFBD16),
      ],
      pressureBg: ProcessModeAssets.pressureMonitoringOrange,
    );
  }
}

/// Triple circular seek arcs (lws-ui laser_progress.xml CircularSeekBars).
///
/// Android style: start_angle=130°, end_angle=50° → 280° sweep; max=100.
final class _LaserDashboardMetrics {
  const _LaserDashboardMetrics._(this.scale);

  factory _LaserDashboardMetrics.fromViewport(Size viewport) =>
      _LaserDashboardMetrics._(ProcessModeDimens.dashboardScaleFor(viewport));

  final double scale;

  double get size => 570 * scale;
  double get height => 603.5 * scale;
  double get outerViewSize => 570 * scale;

  /// Outer rail matches inner rail (lws-ui mini = 50dp; product: outer = inner).
  double get outerCircleStroke => 50 * scale;
  double get outerProgressStroke => 50 * scale;

  double get innerViewSize => 514 * scale;
  double get innerCircleStroke => 50 * scale;
  double get innerProgressStroke => 50 * scale;
  double get lineViewSize => 568 * scale;
  double get lineCircleStroke => 50 * scale;

  /// Thin bright highlight (lws-ui `progress_width` 6dp); flush with outer face.
  double get lineProgressStroke => 6 * scale;

  /// Highlight outside edge stays flush with the outer rail outside edge.
  double get outerHighlightRadius =>
      outerViewSize / 2 - outerCircleStroke / 2 - lineProgressStroke / 2;

  // Exact RelativeLayout child bounds from lws-ui laser_progress.xml.
  double get splitWidth => 500.14 * scale;
  double get splitHeight => 477.48 * scale;
  double get splitLeft => (570 - 500.14) / 2 * scale;
  double get splitTop => 26 * scale;
  double get splitTopWidth => 532.14 * scale;
  double get splitTopHeight => 477.48 * scale;
  double get splitTopLeft => (570 - 532.14) / 2 * scale;
  double get borderWidth => 541 * scale;
  double get borderHeight => 573.5 * scale;
  double get borderLeft => 14 * scale;
  double get borderTop => 30 * scale;
  double get centerSize => 372 * scale;

  double get contentTop => 50 * scale;
  double get contentGap => 5 * scale;
  double get buttonGap => 16.5 * scale;
  double get titleSize => 33 * scale;
  double get valueSize => 101 * scale;
  double get unitSize => 25 * scale;
  /// +2 over prior 20/22 for readability on the HMI panel.
  double get buttonTextSize => 22 * scale;
  double get buttonIconSize => 24 * scale;
  double get buttonIconGap => 4 * scale;

  /// Previous Column layout placed the digit center this far above the circle
  /// midline; centering the digit moves it down by this amount.
  double get pressureValueCenterShiftDown =>
      centerSize / 2 -
      (contentTop + titleSize + contentGap + valueSize / 2);
}

final class _LaserProgressRingsPainter extends CustomPainter {
  _LaserProgressRingsPainter({
    required this.progress,
    required this.palette,
    required this.metrics,
  });

  final double progress;
  final _LaserDashboardPalette palette;
  final _LaserDashboardMetrics metrics;

  /// Matches `quick_mode_circular` start_angle / end_angle.
  static const double _startDeg = 130;
  static const double _totalDeg = 280;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final start = _startDeg * math.pi / 180;
    final fullSweep = _totalDeg * math.pi / 180;
    final progressSweep = fullSweep * progress.clamp(0.0, 1.0);

    // CircularSeekBar radius: viewSize / 2 - circleStrokeWidth.
    _paintRing(
      canvas: canvas,
      center: center,
      viewSize: metrics.outerViewSize,
      circleStrokeWidth: metrics.outerCircleStroke,
      progressStrokeWidth: metrics.outerProgressStroke,
      trackColor: palette.outerTrack,
      progressColors: palette.outerProgress,
      start: start,
      fullSweep: fullSweep,
      progressSweep: progressSweep,
    );

    // Inner seekbar — its 514dp View and 50dp rail are deliberately not
    // derived from the outer ring; they overlap by the Android layout math.
    _paintRing(
      canvas: canvas,
      center: center,
      viewSize: metrics.innerViewSize,
      circleStrokeWidth: metrics.innerCircleStroke,
      progressStrokeWidth: metrics.innerProgressStroke,
      trackColor: palette.innerTrack,
      progressColors: palette.innerProgress,
      start: start,
      fullSweep: fullSweep,
      progressSweep: progressSweep,
    );

    // The source's third CircularSeekBar is an independent 6dp highlight
    // following the circular outer rail. It deliberately stops at the two arc
    // endpoints: do not connect it to the Laser Enable trapezoid border.
    _paintRing(
      canvas: canvas,
      center: center,
      viewSize: metrics.lineViewSize,
      circleStrokeWidth: metrics.lineCircleStroke,
      progressStrokeWidth: metrics.lineProgressStroke,
      // `laser_circular_seek_line` declares `circle_color=transparent` in
      // lws-ui: this layer is only the 6dp progress highlight, never a dark
      // inactive rail outside the static white trim.
      trackColor: Colors.transparent,
      // Product: thin bright edge at 75% opacity.
      progressColors: [
        palette.lineProgress.withOpacity(0.75),
        palette.lineProgress.withOpacity(0.75),
      ],
      start: start,
      fullSweep: fullSweep,
      progressSweep: progressSweep,
      solidProgress: true,
      radius: metrics.outerHighlightRadius,
    );
  }

  void _paintRing({
    required Canvas canvas,
    required Offset center,
    required double viewSize,
    required double circleStrokeWidth,
    required double progressStrokeWidth,
    required Color trackColor,
    required List<Color> progressColors,
    required double start,
    required double fullSweep,
    required double progressSweep,
    bool solidProgress = false,
    double? radius,
  }) {
    final pathRadius = radius ?? viewSize / 2 - circleStrokeWidth;
    final rect = Rect.fromCircle(center: center, radius: pathRadius);

    if (trackColor.alpha > 0) {
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = circleStrokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = trackColor;
      canvas.drawArc(rect, start, fullSweep, false, track);
    }

    if (progressSweep <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = progressStrokeWidth
      ..strokeCap = StrokeCap.butt;

    if (solidProgress) {
      progressPaint.color = progressColors.first;
    } else {
      // Radial gradient across ring thickness (lws-ui CircularSeekColorCall).
      final stops = progressColors.length == 4
          ? <double>[
              (circleStrokeWidth / viewSize).clamp(0.0, 0.49),
              0.5,
              0.9,
              1.0,
            ]
          : null;
      progressPaint.shader = RadialGradient(
        colors: progressColors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: center, radius: viewSize / 2));
    }

    canvas.drawArc(rect, start, progressSweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserProgressRingsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette ||
      oldDelegate.metrics.scale != metrics.scale;
}
