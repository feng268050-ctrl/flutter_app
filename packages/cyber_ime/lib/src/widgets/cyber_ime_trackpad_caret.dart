import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Solid caret overlay while soft-Space Cursor Trackpad Mode is active.
///
/// [TextField.showCursor] is turned off for the duration so framework blink
/// cannot hide the caret mid-drag. This painter follows
/// [TextEditingController.selection] on every rebuild (including each cursor
/// step) so the caret moves in realtime — matching iOS space-trackpad feedback.
class CyberImeTrackpadCaretHost extends StatefulWidget {
  const CyberImeTrackpadCaretHost({
    super.key,
    required this.active,
    required this.controller,
    required this.child,
  });

  final bool active;
  final TextEditingController controller;
  final Widget child;

  @override
  State<CyberImeTrackpadCaretHost> createState() =>
      _CyberImeTrackpadCaretHostState();
}

class _CyberImeTrackpadCaretHostState extends State<CyberImeTrackpadCaretHost> {
  EditableTextState? _editable;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
  }

  @override
  void didUpdateWidget(covariant CyberImeTrackpadCaretHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTick);
      widget.controller.addListener(_onControllerTick);
    }
    if (widget.active && !oldWidget.active) {
      _scheduleSync();
    } else if (!widget.active && oldWidget.active) {
      _editable = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    super.dispose();
  }

  void _onControllerTick() {
    if (!widget.active || !mounted) {
      return;
    }
    _bringCaretOnScreen();
    setState(() {});
  }

  void _scheduleSync() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) {
        return;
      }
      _editable = _findEditableTextState();
      _bringCaretOnScreen();
      setState(() {});
    });
  }

  void _bringCaretOnScreen() {
    final state = _editable ?? _findEditableTextState();
    _editable = state;
    if (state == null) {
      return;
    }
    final sel = widget.controller.selection;
    if (!sel.isValid) {
      return;
    }
    state.bringIntoView(TextPosition(offset: sel.extentOffset));
  }

  EditableTextState? _findEditableTextState() {
    EditableTextState? found;
    void visitor(Element element) {
      if (found != null) {
        return;
      }
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.active)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CyberImeTrackpadCaretPainter(
                  selection: widget.controller.selection,
                  text: widget.controller.text,
                  editable: _editable,
                  hostContext: context,
                  color: _caretColor(context),
                  width: 2.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _caretColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textSelectionTheme.cursorColor ?? theme.colorScheme.primary;
  }
}

class _CyberImeTrackpadCaretPainter extends CustomPainter {
  _CyberImeTrackpadCaretPainter({
    required this.selection,
    required this.text,
    required this.editable,
    required this.hostContext,
    required this.color,
    required this.width,
  });

  final TextSelection selection;
  final String text;
  final EditableTextState? editable;
  final BuildContext hostContext;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final state = editable;
    if (state == null || !selection.isValid || !selection.isCollapsed) {
      return;
    }
    final RenderEditable render;
    try {
      render = state.renderEditable;
    } catch (_) {
      return;
    }
    if (!render.attached) {
      return;
    }
    final hostBox = hostContext.findRenderObject();
    if (hostBox is! RenderBox || !hostBox.hasSize) {
      return;
    }

    final position = TextPosition(
      offset: selection.extentOffset,
      affinity: selection.affinity,
    );
    final caretLocal = render.getLocalRectForCaret(position);
    final globalTopLeft = render.localToGlobal(caretLocal.topLeft);
    final localTopLeft = hostBox.globalToLocal(globalTopLeft);
    final rect = Rect.fromLTWH(
      localTopLeft.dx,
      localTopLeft.dy,
      width,
      caretLocal.height,
    );
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CyberImeTrackpadCaretPainter oldDelegate) {
    return oldDelegate.selection != selection ||
        oldDelegate.text != text ||
        oldDelegate.editable != editable ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
