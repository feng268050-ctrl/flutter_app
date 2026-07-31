import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';

/// Feed hold L→R fill progress (press → 3s latch window).
///
/// Forward lasts [DeviceControlTiming.wireFeedLatchDelay]. Early release
/// reverses to 0 over the elapsed hold time. Latch snaps to 1 and stops.
final class FeedHoldProgressController {
  FeedHoldProgressController({
    required TickerProvider vsync,
    this.onChanged,
    this.onFillCompleted,
  }) : _controller = AnimationController(
          vsync: vsync,
          duration: DeviceControlTiming.wireFeedLatchDelay,
        ) {
    _controller.addListener(_notify);
    _controller.addStatusListener(_onStatus);
  }

  final VoidCallback? onChanged;

  /// Fired once when the forward L→R fill reaches 1 (still not latched).
  final VoidCallback? onFillCompleted;

  final AnimationController _controller;

  bool _latched = false;

  Animation<double> get animation => _controller;

  double get value => _controller.value;

  bool get isAnimating => _controller.isAnimating;

  bool get showsFill => value > 0 && !_latched;

  bool get latched => _latched;

  void _notify() => onChanged?.call();

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_latched) {
      onFillCompleted?.call();
    }
    if (status == AnimationStatus.dismissed) {
      _notify();
    }
  }

  /// Start 0→1 over the 3s latch window.
  void onPressStart() {
    _latched = false;
    _controller.stop();
    _controller.duration = DeviceControlTiming.wireFeedLatchDelay;
    _controller.forward(from: 0);
  }

  /// Early release: reverse to 0 over the time already held.
  ///
  /// Duration matches the linear forward so far (`value * 3s`), equivalent to
  /// wall-clock hold when the fill runs on time.
  void onPressEndEarly() {
    if (_latched) {
      return;
    }
    if (value <= 0) {
      _controller.stop();
      _controller.value = 0;
      _notify();
      return;
    }
    final reverseMs =
        (value * DeviceControlTiming.wireFeedLatchDelay.inMilliseconds)
            .round()
            .clamp(1, 3000);
    _controller.stop();
    _controller.animateTo(
      0,
      duration: Duration(milliseconds: reverseMs),
      curve: Curves.linear,
    );
  }

  /// Hold reached continuous-feed latch — solid face takes over.
  void onLatched() {
    _latched = true;
    _controller.stop();
    _controller.value = 1;
    _notify();
  }

  /// Tap-to-stop continuous feed or hard reset.
  void reset() {
    _latched = false;
    _controller.stop();
    _controller.value = 0;
    _notify();
  }

  void dispose() {
    _controller.removeListener(_notify);
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
  }
}

/// Left-aligned orange fill under Feed chrome while holding / reversing.
final class FeedHoldProgressFill extends StatelessWidget {
  const FeedHoldProgressFill({
    super.key,
    required this.progress,
    this.radius = 14,
    this.color = const Color(0xFFF46E01),
  });

  final double progress;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) {
      return const SizedBox.shrink();
    }
    return FractionallySizedBox(
      widthFactor: t,
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Soft L→R sheen looped on the solid Continuous Feed face.
///
/// Drawn above the solid orange fill (not a replacement): a brighter band
/// sweeps left→right, then repeats — continuous-feed “波纹扩散”.
final class FeedContinuousRipple extends StatefulWidget {
  const FeedContinuousRipple({
    super.key,
    this.period = const Duration(milliseconds: 1400),
    this.highlight = const Color(0x66FFFFFF),
  });

  final Duration period;
  final Color highlight;

  @override
  State<FeedContinuousRipple> createState() => _FeedContinuousRippleState();
}

final class _FeedContinuousRippleState extends State<FeedContinuousRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void didUpdateWidget(covariant FeedContinuousRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
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
      builder: (context, _) {
        return CustomPaint(
          painter: _FeedContinuousRipplePainter(
            t: _controller.value,
            highlight: widget.highlight,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

final class _FeedContinuousRipplePainter extends CustomPainter {
  _FeedContinuousRipplePainter({
    required this.t,
    required this.highlight,
  });

  final double t;
  final Color highlight;

  /// Soft band width as a fraction of the face.
  static const double _band = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    // Soft band sweeps fully across: starts off-left, exits off-right.
    final bandW = size.width * _band;
    final x = (t * (size.width + bandW)) - bandW;
    final rect = Rect.fromLTWH(x, 0, bandW, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0x00FFFFFF),
          highlight,
          const Color(0x00FFFFFF),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _FeedContinuousRipplePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.highlight != highlight;
  }
}
