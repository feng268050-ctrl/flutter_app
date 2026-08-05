import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_navigation.dart';

/// Tap-driven horizontal slide body for Settings / Monitor tabs.
///
/// Finger swipe stays disabled (anti-mis-touch); tab taps animate L/R like
/// in-module [buildAppSlideRoute] navigation. Children are keep-alive so tab
/// state matches the previous [IndexedStack] behavior.
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

class _ProductTabSlideBodyState extends State<ProductTabSlideBody> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.index);
  }

  @override
  void didUpdateWidget(covariant ProductTabSlideBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) {
      return;
    }
    if (!_controller.hasClients) {
      return;
    }
    final current = _controller.page?.round() ?? _controller.initialPage;
    if (current == widget.index) {
      return;
    }
    _controller.animateToPage(
      widget.index,
      duration: widget.duration,
      curve: widget.curve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final child in widget.children) _KeepAliveTabPage(child: child),
      ],
    );
  }
}

class _KeepAliveTabPage extends StatefulWidget {
  const _KeepAliveTabPage({required this.child});

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
