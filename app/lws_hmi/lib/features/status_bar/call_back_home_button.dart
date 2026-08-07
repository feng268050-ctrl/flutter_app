import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Back / Home rail (lws-ui `status_call_back_home`).
///
/// Idle = transparent (+ optional accent edge lines); pressed = translucent
/// accent fill. Leading glyph: [Icons.home_outlined] when [useHomeIcon] is
/// true, or when unset and [label] is Home; otherwise [Icons.arrow_back].
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

  /// Rail width matching lws-ui `equipment_status_side_rail_width`.
  static const double railWidth = 160;

  final WorkModeAccent accent;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  /// When true (legacy fixed rail), fills the parent width and may ellipsize.
  /// When false (Quick / Engineer / Settings·Monitor titles), sizes to the
  /// icon + full label so text is never truncated.
  final bool expandWidth;

  /// Force Home vs Back glyph independent of [label].
  ///
  /// Settings / Monitor roots pass `true` while the label shows the tab title.
  /// Nested pages leave this null (arrow) or set `false`.
  final bool? useHomeIcon;

  /// Top/bottom orange edge lines. Settings / Monitor pass `false`.
  final bool showEdgeAccent;

  /// Intrinsic width for [label] at product chrome size (icon + paddings).
  static double widthForLabel(
    String label, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: _kHomeLabelFontSize,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    // +24 slack: painter can undershoot real glyph advance / font fallback.
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
/// Ladder: navigation / primaryTabLabel (24).
const _kHomeLabelFontSize = 24.0;
const _kBackLabelDisabled = Color(0xFF909399);

final class _CallBackHomeButtonState extends State<CallBackHomeButton> {
  bool _pressed = false;

  IconData _leadingIcon(BuildContext context) {
    final forced = widget.useHomeIcon;
    if (forced != null) {
      return forced ? Icons.home_outlined : Icons.arrow_back;
    }
    final home = AppLocalizations.of(context)?.equipmentStatusHome;
    if (home != null && widget.label == home) {
      return Icons.home_outlined;
    }
    // Fallback for callers that hard-code English "Home".
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
      padding: const EdgeInsets.symmetric(
        horizontal: _kBackHorizontalPadding,
      ),
      child: Row(
        mainAxisAlignment:
            expand ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _leadingIcon(context),
            size: _kBackIconSize,
            color: iconColor,
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
                  fontSize: _kHomeLabelFontSize,
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
                fontSize: _kHomeLabelFontSize,
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
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }
}
