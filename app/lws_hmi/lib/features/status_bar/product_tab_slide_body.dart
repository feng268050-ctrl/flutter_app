import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';

/// Tap-driven horizontal slide body for Settings / Monitor tabs.
///
/// Finger swipe stays disabled (anti-mis-touch); tab taps animate L/R like
/// in-module [buildAppSlideRoute] navigation.
///
/// Unlike [PageView.animateToPage], non-adjacent jumps only paint the outgoing
/// and incoming tabs (no intermediate-page sweep) — critical on RK3566 when
/// Monitor keeps several heavy bodies alive.
class ProductTabSlideBody extends StatefulWidget {
  const ProductTabSlideBody({
    super.key,
    required this.index,
    required this.children,
    this.duration = kAppPageEnterDuration,
    this.curve = Curves.easeInOut,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  @override
  State<ProductTabSlideBody> createState() => _ProductTabSlideBodyState();
}

class _ProductTabSlideBodyState extends State<ProductTabSlideBody>
    with SingleTickerProviderStateMixin {
  late int _index;
  int? _outgoingIndex;
  bool _forward = true;
  late final AnimationController _controller;
  late CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatus);
    _curved = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    if (_outgoingIndex == null || !mounted) {
      return;
    }
    setState(() => _outgoingIndex = null);
    _controller.reset();
  }

  @override
  void didUpdateWidget(covariant ProductTabSlideBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.curve != oldWidget.curve) {
      _curved.dispose();
      _curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    }
    if (widget.index == _index) {
      return;
    }
    if (_controller.isAnimating) {
      _controller.stop();
      _outgoingIndex = null;
    }
    setState(() {
      _forward = widget.index > _index;
      _outgoingIndex = _index;
      _index = widget.index;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  Animation<Offset> _offsetFor(int i) {
    if (_outgoingIndex == null) {
      return const AlwaysStoppedAnimation(Offset.zero);
    }
    if (i == _index) {
      final beginDx = _forward ? 1.0 : -1.0;
      return Tween<Offset>(
        begin: Offset(beginDx, 0),
        end: Offset.zero,
      ).animate(_curved);
    }
    if (i == _outgoingIndex) {
      final endDx = _forward ? -1.0 : 1.0;
      return Tween<Offset>(
        begin: Offset.zero,
        end: Offset(endDx, 0),
      ).animate(_curved);
    }
    return const AlwaysStoppedAnimation(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < widget.children.length; i++)
            Offstage(
              offstage: i != _index && i != _outgoingIndex,
              child: TickerMode(
                // Keep the incoming tab live; freeze outgoing + hidden tabs.
                enabled: i == _index,
                child: SlideTransition(
                  position: _offsetFor(i),
                  child: _KeepAliveTabPage(
                    key: ValueKey<int>(i),
                    child: widget.children[i],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single-child L/R slide when the keyed [child] changes (Engineer process tabs).
///
/// Prefer this over [ProductTabSlideBody] when only one tab body may be mounted
/// (shared [GlobalKey] / controllers). Set [forward] from old→new tab index.
class ProductTabSlideSwitcher extends StatelessWidget {
  const ProductTabSlideSwitcher({
    super.key,
    required this.forward,
    required this.child,
    this.duration = kAppPageEnterDuration,
    this.curve = Curves.easeInOut,
  });

  /// True when switching to a higher tab index (enter from right).
  final bool forward;
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (incoming, animation) {
        // Incoming uses [forward]; outgoing (reversed animation) exits the
        // opposite edge so both panels slide the same direction.
        final isIncoming = identical(incoming, child) ||
            (incoming.key != null &&
                child.key != null &&
                incoming.key == child.key);
        final beginDx = isIncoming
            ? (forward ? 1.0 : -1.0)
            : (forward ? -1.0 : 1.0);
        return ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(beginDx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: incoming,
          ),
        );
      },
      child: child,
    );
  }
}

class _KeepAliveTabPage extends StatefulWidget {
  const _KeepAliveTabPage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAliveTabPage> createState() => _KeepAliveTabPageState();
}

class _KeepAliveTabPageState extends State<_KeepAliveTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
