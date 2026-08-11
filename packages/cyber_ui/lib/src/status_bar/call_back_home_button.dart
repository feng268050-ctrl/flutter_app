import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/status_bar/cyber_status_bar_accent.dart';
import 'package:flutter/material.dart';

/// Product Back / Home rail (lws-ui `status_call_back_home`).
final class CallBackHomeButton extends StatefulWidget {
  const CallBackHomeButton({
    super.key,
    required this.accent,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.expandWidth = true,
    this.useHomeIcon,
    this.showEdgeAccent = true,
  });

  static const double railWidth = 160;
  static const double labelFontSize = 24;

  final CyberStatusBarAccent accent;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool expandWidth;
  final bool? useHomeIcon;
  final bool showEdgeAccent;

  static double widthForLabel(
    String label, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: CallBackHomeButton.labelFontSize,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return _kBackHorizontalPadding * 2 +
        _kBackIconSize +
        8 +
        painter.width +
        24;
  }

  @override
  State<CallBackHomeButton> createState() => _CallBackHomeButtonState();
}

const _kBackIconSize = 34.0;
const _kBackHorizontalPadding = 12.0;
const _kEdgeLineHeight = 3.0;
const _kBackLabelDisabled = Color(0xFF909399);

final class _CallBackHomeButtonState extends State<CallBackHomeButton> {
  bool _pressed = false;

  IconData _leadingIcon() {
    final forced = widget.useHomeIcon;
    if (forced != null) {
      return forced ? Icons.home_outlined : Icons.arrow_back;
    }
    if (widget.label == 'Home') {
      return Icons.home_outlined;
    }
    return Icons.arrow_back;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final enabled = widget.enabled;
    final labelColor = enabled ? Colors.white : _kBackLabelDisabled;
    final iconColor = enabled ? Colors.white : _kBackLabelDisabled;
    final expand = widget.expandWidth;

    final labelRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kBackHorizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _kBackIconSize,
            height: _kBackIconSize,
            child: Icon(
              _leadingIcon(),
              size: _kBackIconSize,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 8),
          if (expand)
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: CallBackHomeButton.labelFontSize,
                  height: 1,
                ),
              ),
            )
          else
            Text(
              widget.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: labelColor,
                fontSize: CallBackHomeButton.labelFontSize,
                fontWeight: FontWeight.w400,
                height: 1,
              ),
            ),
        ],
      ),
    );

    final face = Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('call-back-home-button'),
        onTap: enabled
            ? () {
                CyberClickSoundRegistry.playClick();
                widget.onPressed();
              }
            : null,
        onHighlightChanged: enabled
            ? (value) {
                if (_pressed != value) {
                  setState(() => _pressed = value);
                }
              }
            : null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: (_pressed && enabled) ? accent.pressGradient : null,
          ),
          child: expand ? SizedBox.expand(child: labelRow) : labelRow,
        ),
      ),
    );

    final showEdges = widget.showEdgeAccent;
    final column = Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (showEdges) _AccentEdgeLine(gradient: accent.edgeGradient),
        Expanded(child: face),
        if (showEdges) _AccentEdgeLine(gradient: accent.edgeGradient),
      ],
    );

    if (expand) {
      return column;
    }
    return IntrinsicWidth(child: column);
  }
}

final class _AccentEdgeLine extends StatelessWidget {
  const _AccentEdgeLine({required this.gradient});

  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kEdgeLineHeight,
      width: double.infinity,
      child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
    );
  }
}
