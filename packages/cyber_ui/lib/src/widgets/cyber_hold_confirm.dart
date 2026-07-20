import 'package:flutter/material.dart';

import 'package:cyber_ui/src/sound/cyber_click_sound.dart';
import 'package:cyber_ui/src/theme/cyber_colors.dart';
import 'package:cyber_ui/src/theme/cyber_dimens.dart';

/// Hold-to-confirm control (simplified Frost HoldConfirm).
class CyberHoldConfirm extends StatefulWidget {
  const CyberHoldConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 800),
    this.clickSoundEnabled = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final bool clickSoundEnabled;

  @override
  State<CyberHoldConfirm> createState() => _CyberHoldConfirmState();
}

class _CyberHoldConfirmState extends State<CyberHoldConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_fired) {
          _fired = true;
          if (widget.clickSoundEnabled) {
            CyberClickSoundRegistry.playClick();
          }
          widget.onConfirmed();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _cancel() {
    _fired = false;
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _fired = false;
        _ctrl.forward(from: 0);
      },
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Container(
            height: CyberDimens.actionButtonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(CyberDimens.rectangleButtonCornerRadius),
              border: Border.all(color: CyberColors.borderHighlight),
              gradient: LinearGradient(
                colors: [
                  CyberColors.buttonPrimaryAccent
                      .withOpacity(0.25 + 0.55 * _ctrl.value),
                  CyberColors.fillMid,
                ],
              ),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: CyberColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }
}
