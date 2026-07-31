import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Product Back / Home rail (lws-ui `status_call_back_home`).
///
/// Idle = transparent + accent edge lines; pressed = translucent accent fill.
/// Leading glyph: [Icons.home_outlined] when [label] is Home, else
/// [Icons.arrow_back] (Material; same pop action either way).
final class CallBackHomeButton extends StatefulWidget {
  const CallBackHomeButton({
    super.key,
    required this.accent,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  /// Rail width matching lws-ui `equipment_status_side_rail_width`.
  static const double railWidth = 160;

  final WorkModeAccent accent;
  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<CallBackHomeButton> createState() => _CallBackHomeButtonState();
}

const _kBackIconSize = 34.0;
const _kBackHorizontalPadding = 12.0;
const _kEdgeLineHeight = 3.0;
const _kHomeLabelFontSize = 24.0;
const _kBackLabelDisabled = Color(0xFF909399);

final class _CallBackHomeButtonState extends State<CallBackHomeButton> {
  bool _pressed = false;

  IconData _leadingIcon(BuildContext context) {
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

    return Column(
      children: [
        _AccentEdgeLine(gradient: accent.edgeGradient),
        Expanded(
          child: Material(
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
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kBackHorizontalPadding,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _leadingIcon(context),
                          size: _kBackIconSize,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _AccentEdgeLine(gradient: accent.edgeGradient),
      ],
    );
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
