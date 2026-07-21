import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:cyber_ui/src/widgets/cyber_keyboard_insets.dart';

/// Lifts [child] only as needed to stay visible above a keyboard band.
///
/// Unlike blind full-height translation, this recenters (or pins) the card in
/// the remaining viewport — matching lws-ui IME card lift.
class CyberKeyboardAvoidingLift extends StatefulWidget {
  const CyberKeyboardAvoidingLift({
    super.key,
    required this.keyboardHeight,
    required this.child,
    this.margin = CyberKeyboardInsets.defaultMargin,
  });

  /// Height of the soft-keyboard panel (logical px). Zero when hidden.
  final ValueListenable<double> keyboardHeight;
  final double margin;
  final Widget child;

  @override
  State<CyberKeyboardAvoidingLift> createState() =>
      _CyberKeyboardAvoidingLiftState();
}

class _CyberKeyboardAvoidingLiftState extends State<CyberKeyboardAvoidingLift> {
  final GlobalKey _cardKey = GlobalKey();
  double _translationY = 0;
  bool _frameScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.keyboardHeight.addListener(_scheduleRecompute);
  }

  @override
  void didUpdateWidget(covariant CyberKeyboardAvoidingLift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyboardHeight != widget.keyboardHeight) {
      oldWidget.keyboardHeight.removeListener(_scheduleRecompute);
      widget.keyboardHeight.addListener(_scheduleRecompute);
      _scheduleRecompute();
    } else if (oldWidget.margin != widget.margin) {
      _scheduleRecompute();
    }
  }

  @override
  void dispose() {
    widget.keyboardHeight.removeListener(_scheduleRecompute);
    super.dispose();
  }

  void _scheduleRecompute() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      _recompute();
    });
  }

  void _recompute() {
    final keyboardHeight = widget.keyboardHeight.value;
    if (keyboardHeight < CyberKeyboardInsets.visibleThreshold) {
      if (_translationY != 0) {
        setState(() => _translationY = 0);
      }
      return;
    }

    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final size = MediaQuery.sizeOf(context);
    // localToGlobal includes the current transform — recover layout top.
    final paintedTop = box.localToGlobal(Offset.zero).dy;
    final baseTop = paintedTop - _translationY;
    final visibleBottom = size.height - keyboardHeight;
    final next = CyberKeyboardInsets.computeCardTranslationY(
      visibleTop: 0,
      visibleBottom: visibleBottom,
      cardTop: baseTop,
      cardHeight: box.size.height,
      keyboardHeight: keyboardHeight,
      margin: widget.margin,
    );

    if ((next - _translationY).abs() > 0.5) {
      setState(() => _translationY = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recompute after layout so card size/position are known.
    _scheduleRecompute();
    return Transform.translate(
      offset: Offset(0, _translationY),
      child: KeyedSubtree(
        key: _cardKey,
        child: widget.child,
      ),
    );
  }
}
