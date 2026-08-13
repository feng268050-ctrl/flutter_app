import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Shared Quick Mode offset wheel: fixed selection chrome, scroll-linked
/// item styling, and tap-to-position (lws-ui `setClickToPosition(true)`).
///
/// Switch SFX + parent [onChanged]: silent / deferred while the finger is
/// down. Committing mid-drag rebuilds the parent (e.g. entering CNC Cutting)
/// and [jumpToItem]s, which aborts the fling — so selection is reported on
/// scroll-end / tap only.
final class QuickModeOffsetWheel extends StatefulWidget {
  const QuickModeOffsetWheel({
    super.key,
    required this.itemCount,
    required this.selectedIndex,
    required this.itemExtent,
    required this.onChanged,
    required this.itemBuilder,
    this.diameterRatio = 100,
    this.perspective = 0.001,
    this.offAxisFraction = 0,
    this.fixedAccent,
    this.enabled = true,
  });

  final int itemCount;
  final int selectedIndex;
  final double itemExtent;
  final ValueChanged<int> onChanged;
  final Widget Function(
    BuildContext context,
    int index,
    double signedDistanceFromCenter,
  ) itemBuilder;
  final double diameterRatio;
  final double perspective;
  final double offAxisFraction;

  /// Drawn behind the wheel at the vertical center; does not scroll.
  final Widget? fixedAccent;

  /// When false, scroll/tap are ignored (lws-ui `switchEnableStatus(false)`).
  final bool enabled;

  @override
  State<QuickModeOffsetWheel> createState() => _QuickModeOffsetWheelState();
}

final class _QuickModeOffsetWheelState extends State<QuickModeOffsetWheel> {
  late FixedExtentScrollController _controller;
  late int _index;

  /// Continuous center index from scroll offset (for visual styling).
  double _scrollIndex = 0;

  /// User finger-drag in progress (not a programmatic animateToItem).
  bool _userDragging = false;

  /// Selection when the current drag started (for release SFX).
  int _indexAtDragStart = 0;

  /// While true, [onSelectedItemChanged] intermediates from a tap animation
  /// must not re-fire [onChanged] (target was already reported).
  bool _ignoreSelectionCallbacks = false;

  static const Duration _tapDuration = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    _index = _clamped(widget.selectedIndex);
    _scrollIndex = _index.toDouble();
    _controller = FixedExtentScrollController(initialItem: _index);
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant QuickModeOffsetWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _clamped(widget.selectedIndex);
    final countChanged = oldWidget.itemCount != widget.itemCount;
    if (!countChanged && next == _index) {
      return;
    }
    // Mid-drag: keep the finger's local index. Parent still has the pre-drag
    // selection; jumping would abort continuous swipe (CNC enter/leave).
    if (_userDragging && !countChanged) {
      return;
    }
    _index = next;
    _scrollIndex = next.toDouble();
    if (_controller.hasClients) {
      _controller.jumpToItem(next);
    } else {
      _controller.removeListener(_onScroll);
      _controller.dispose();
      _controller = FixedExtentScrollController(initialItem: next);
      _controller.addListener(_onScroll);
    }
  }

  int _clamped(int index) {
    if (widget.itemCount <= 0) {
      return 0;
    }
    return index.clamp(0, widget.itemCount - 1);
  }

  void _onScroll() {
    if (!_controller.hasClients) {
      return;
    }
    final next = _controller.offset / widget.itemExtent;
    if ((next - _scrollIndex).abs() < 0.001) {
      return;
    }
    setState(() => _scrollIndex = next);
  }

  void _commitIfNeeded(int index) {
    if (!widget.enabled) {
      return;
    }
    if (index == widget.selectedIndex) {
      return;
    }
    widget.onChanged(index);
  }

  void _onSelected(int index) {
    if (!widget.enabled) {
      return;
    }
    if (_ignoreSelectionCallbacks) {
      return;
    }
    if (index == _index) {
      return;
    }
    setState(() {
      _index = index;
    });
    // Defer parent notify while dragging — mid-drag setState in ancestors
    // (process-type / CNC enter) jumpToItem and kill the gesture.
    if (_userDragging) {
      return;
    }
    _commitIfNeeded(index);
  }

  void _onItemTap(int index) {
    if (!widget.enabled) {
      return;
    }
    if (index < 0 || index >= widget.itemCount) {
      return;
    }
    if (!_controller.hasClients) {
      if (index != _index) {
        CyberClickSoundRegistry.playClick();
        setState(() {
          _index = index;
          _scrollIndex = index.toDouble();
        });
        _commitIfNeeded(index);
      }
      return;
    }
    if (index == _controller.selectedItem) {
      return;
    }
    // Notify parent immediately (lws-ui click path is sync); suppress
    // intermediate onSelectedItemChanged while the short settle anim runs.
    CyberClickSoundRegistry.playClick();
    setState(() {
      _index = index;
    });
    _commitIfNeeded(index);
    _ignoreSelectionCallbacks = true;
    unawaited(
      _controller
          .animateToItem(
            index,
            duration: _tapDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
        _ignoreSelectionCallbacks = false;
      }),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!widget.enabled) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userDragging = true;
      _indexAtDragStart = _index;
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle &&
        _userDragging) {
      // Wait for ballistic settle too — ScrollEnd of the drag alone would
      // commit early and parent jumpToItem would kill the fling (CNC swipe).
      _userDragging = false;
      if (_index != _indexAtDragStart) {
        CyberClickSoundRegistry.playClick();
      }
      _commitIfNeeded(_index);
    }
    return false;
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) {
      return const SizedBox.shrink();
    }
    final wheel = Stack(
      alignment: Alignment.center,
      children: [
        if (widget.fixedAccent != null)
          IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: widget.fixedAccent,
            ),
          ),
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: widget.itemExtent,
            diameterRatio: widget.diameterRatio,
            perspective: widget.perspective,
            offAxisFraction: widget.offAxisFraction,
            physics: widget.enabled
                ? const FixedExtentScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onSelectedItemChanged: _onSelected,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.itemCount,
              builder: (context, index) {
                // Keep this signed and fractional. Arc wheels derive their
                // per-frame Y/X position from the live scroll offset; taking
                // abs here or snapping it in [_onSelected] loses direction
                // and introduces a horizontal jump at half-item boundaries.
                final distance = index - _scrollIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.enabled ? () => _onItemTap(index) : null,
                  child: widget.itemBuilder(context, index, distance),
                );
              },
            ),
          ),
        ),
      ],
    );
    if (widget.enabled) {
      return wheel;
    }
    return AbsorbPointer(child: wheel);
  }
}
