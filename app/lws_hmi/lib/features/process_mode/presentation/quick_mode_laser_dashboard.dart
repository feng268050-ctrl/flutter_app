import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';

/// Center laser instrument cluster — Flutter port of lws-ui `LaserProgress`.
///
/// Layers: outer/inner progress rings + thin highlight arc + decorative mipmaps
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
    final size = ProcessModeDimens.dashboardSize;
    final inner = ProcessModeDimens.dashboardInnerSize;
    final ringAlpha = widget.laserEnable ? 1.0 : 0.5;
    final pressureText = widget.gasPressureKpa.round().toString();

    return SizedBox(
      key: const ValueKey('quick-mode-laser-dashboard'),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Rings + chrome (alpha 0.5 when laser enable off).
          Opacity(
            opacity: ringAlpha,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(size, size),
                  painter: _LaserProgressRingsPainter(
                    progress: _progress / 100.0,
                    palette: palette,
                  ),
                ),
                Image.asset(
                  ProcessModeAssets.circleSplitBorderTop,
                  width: ProcessModeDimens.dashboardSplitTopWidth,
                  height: ProcessModeDimens.dashboardSplitTopHeight,
                  fit: BoxFit.contain,
                  opacity: const AlwaysStoppedAnimation(0.8),
                ),
                Transform.translate(
                  offset: const Offset(
                    0,
                    ProcessModeDimens.dashboardSplitOffsetY,
                  ),
                  child: Image.asset(
                    ProcessModeAssets.circleSplitBorder,
                    width: ProcessModeDimens.dashboardSplitWidth,
                    height: ProcessModeDimens.dashboardSplitHeight,
                    fit: BoxFit.contain,
                    opacity: const AlwaysStoppedAnimation(0.3),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(
                    0,
                    ProcessModeDimens.dashboardBorderOffsetY,
                  ),
                  child: Image.asset(
                    ProcessModeAssets.circleBorder,
                    width: ProcessModeDimens.dashboardBorderWidth,
                    height: ProcessModeDimens.dashboardBorderHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          // Center pressure panel — topmost, 372×372 (laser_progress.xml).
          SizedBox(
            width: inner,
            height: inner,
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(palette.pressureBg),
                  fit: BoxFit.cover,
                ),
                shape: BoxShape.circle,
              ),
              child: Column(
                children: [
                  const SizedBox(
                    height: ProcessModeDimens.dashboardContentTop,
                  ),
                  const Text(
                    'Gas Pressure',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF), // alpha 0.8
                      fontSize: ProcessModeDimens.dashboardTitleSize,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(
                    height: ProcessModeDimens.dashboardContentGap,
                  ),
                  Text(
                    pressureText,
                    key: const ValueKey('quick-mode-gas-pressure'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: ProcessModeDimens.dashboardValueSize,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(
                    height: ProcessModeDimens.dashboardContentGap,
                  ),
                  const Text(
                    'kPa',
                    style: TextStyle(
                      color: Color(0x66FFFFFF), // alpha 0.4
                      fontSize: ProcessModeDimens.dashboardUnitSize,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(
                    height: ProcessModeDimens.dashboardButtonGap,
                  ),
                  TextButton(
                    key: const ValueKey('quick-mode-more-status'),
                    onPressed: widget.onMoreStatus ??
                        () =>
                            Navigator.of(context).pushNamed(AppRoutes.monitor),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0x33FFFFFF),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16 * ProcessModeDimens.dashboardScale,
                        vertical: 8 * ProcessModeDimens.dashboardScale,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'More Status',
                          style: TextStyle(
                            fontSize: ProcessModeDimens.dashboardButtonTextSize,
                          ),
                        ),
                        SizedBox(
                          width: ProcessModeDimens.dashboardButtonIconGap,
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: ProcessModeDimens.dashboardButtonIconSize,
                        ),
                      ],
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
final class _LaserProgressRingsPainter extends CustomPainter {
  _LaserProgressRingsPainter({
    required this.progress,
    required this.palette,
  });

  final double progress;
  final _LaserDashboardPalette palette;

  /// Matches `quick_mode_circular` start_angle / end_angle.
  static const double _startDeg = 130;
  static const double _totalDeg = 280;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final start = _startDeg * math.pi / 180;
    final fullSweep = _totalDeg * math.pi / 180;
    final progressSweep = fullSweep * progress.clamp(0.0, 1.0);

    // Outer ring — 570 layout, stroke/progress 38 (scaled).
    _paintRing(
      canvas: canvas,
      center: center,
      layoutSize: ProcessModeDimens.dashboardOuterRing,
      strokeWidth: ProcessModeDimens.dashboardOuterStroke,
      trackColor: palette.outerTrack.withOpacity(0.45),
      progressColors: palette.outerProgress,
      start: start,
      fullSweep: fullSweep,
      progressSweep: progressSweep,
    );

    // Inner dark rail — same stroke as outer rail (1:1), nested inside it.
    _paintRing(
      canvas: canvas,
      center: center,
      layoutSize: ProcessModeDimens.dashboardInnerRing,
      strokeWidth: ProcessModeDimens.dashboardInnerStroke,
      trackColor: palette.innerTrack.withOpacity(0.55),
      progressColors: palette.innerProgress,
      start: start,
      fullSweep: fullSweep,
      progressSweep: progressSweep,
    );

    // Thin bright line — path radius matches outer rail outer face.
    _paintRing(
      canvas: canvas,
      center: center,
      layoutSize: ProcessModeDimens.dashboardLineRing,
      strokeWidth: ProcessModeDimens.dashboardLineStroke,
      trackColor: palette.lineProgress.withOpacity(0.35),
      progressColors: [
        palette.lineProgress,
        palette.lineProgress,
      ],
      start: start,
      fullSweep: fullSweep,
      progressSweep: progressSweep,
      solidProgress: true,
    );
  }

  void _paintRing({
    required Canvas canvas,
    required Offset center,
    required double layoutSize,
    required double strokeWidth,
    required Color trackColor,
    required List<Color> progressColors,
    required double start,
    required double fullSweep,
    required double progressSweep,
    bool solidProgress = false,
  }) {
    // Stroke is centered on [radius]; layoutSize is the outer diameter of the stroke.
    final radius = layoutSize / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (trackColor.alpha > 0) {
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = trackColor;
      canvas.drawArc(rect, start, fullSweep, false, track);
    }

    if (progressSweep <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (solidProgress) {
      progressPaint.color = progressColors.first;
    } else {
      // Radial gradient across ring thickness (lws-ui CircularSeekColorCall).
      final stops = progressColors.length == 4
          ? <double>[
              (strokeWidth / (layoutSize)).clamp(0.0, 0.49),
              0.5,
              0.9,
              1.0,
            ]
          : null;
      progressPaint.shader = RadialGradient(
        colors: progressColors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: center, radius: layoutSize / 2));
    }

    canvas.drawArc(rect, start, progressSweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserProgressRingsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.palette != palette;
}
