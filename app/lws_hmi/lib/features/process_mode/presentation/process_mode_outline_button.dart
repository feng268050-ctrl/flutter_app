import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';

/// Engineer Retract/Feed outline chrome — reused by Quick Mode side ops.
///
/// Visual: orange rim, dark fill; filled orange + white label when active.
abstract final class ProcessModeOutlineChrome {
  static const Color actionOrange = Color(0xFFF46E01);
  static const Color idleFill = Color(0xFF2C1923);
  static const Color disabledForeground = Color(0xFF7D3E2B);
  /// Quick side ops: +6 vs Engineer wire face (16).
  static const double labelSize = 22.0;
  static const double iconSize = 22.0;
  static const double radius = 14.0;
  static const double strokeWidth = 1.5;
  static const double defaultHeight = 62.0;
}

/// Tap outline button (Quick Manual Gas / Auto Wire).
final class ProcessModeOutlineButton extends StatelessWidget {
  const ProcessModeOutlineButton({
    super.key,
    required this.label,
    required this.leading,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    this.height = ProcessModeOutlineChrome.defaultHeight,
  });

  final String label;
  final Widget leading;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final highlight = enabled && selected;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  CyberClickSoundRegistry.playClick();
                  onPressed?.call();
                }
              : null,
          borderRadius:
              BorderRadius.circular(ProcessModeOutlineChrome.radius),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: _OutlineFace(
              height: height,
              highlight: highlight,
              enabled: enabled,
              leading: leading,
              label: label,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hold/pulse Feed·Retract — same face as Engineer `_EngineerWireActionButton`.
final class ProcessModeOutlineWireButton extends StatefulWidget {
  const ProcessModeOutlineWireButton({
    super.key,
    required this.label,
    required this.leading,
    required this.enabled,
    required this.laserBlocked,
    required this.retract,
    required this.active,
    required this.controller,
    required this.onMessage,
    this.height = ProcessModeOutlineChrome.defaultHeight,
    this.latchedLabel,
  });

  final String label;
  final Widget leading;
  final bool enabled;
  final bool laserBlocked;
  final bool retract;
  final bool active;
  final DeviceControlController controller;
  final ValueChanged<String> onMessage;
  final double height;
  final String? latchedLabel;

  @override
  State<ProcessModeOutlineWireButton> createState() =>
      _ProcessModeOutlineWireButtonState();
}

final class _ProcessModeOutlineWireButtonState
    extends State<ProcessModeOutlineWireButton> {
  late final ManualWireGesture _gesture = ManualWireGesture(
    controller: widget.controller,
    retract: widget.retract,
    isEnabled: () => widget.enabled,
    isActive: () => widget.active,
    onMessage: widget.onMessage,
    onVisualChanged: () {
      if (mounted) {
        setState(() {});
      }
    },
  );

  @override
  void dispose() {
    _gesture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latched = !widget.retract && _gesture.latched;
    final highlight = widget.enabled &&
        (widget.active || _gesture.pressed || _gesture.holdingRun || latched);
    final label = latched
        ? (widget.latchedLabel ?? widget.label)
        : widget.label;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: label,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (!widget.enabled) {
            return;
          }
          if (widget.controller.busy) {
            widget.onMessage(LaserEnableBlockReason.busy.message);
            return;
          }
          if (widget.laserBlocked) {
            widget.onMessage(DeviceControlFeedbackCopy.endOfWorkFirst);
            return;
          }
          CyberClickSoundRegistry.playClick();
          _gesture.pointerDown();
        },
        onPointerUp: (_) {
          if (!widget.enabled ||
              widget.controller.busy ||
              widget.laserBlocked) {
            return;
          }
          _gesture.pointerUp();
        },
        onPointerCancel: (_) {
          if (!widget.enabled ||
              widget.controller.busy ||
              widget.laserBlocked) {
            return;
          }
          _gesture.pointerUp();
        },
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: _OutlineFace(
            height: widget.height,
            highlight: highlight,
            enabled: widget.enabled,
            leading: widget.leading,
            label: label,
          ),
        ),
      ),
    );
  }
}

final class _OutlineFace extends StatelessWidget {
  const _OutlineFace({
    required this.height,
    required this.highlight,
    required this.enabled,
    required this.leading,
    required this.label,
  });

  final double height;
  final bool highlight;
  final bool enabled;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? ProcessModeOutlineChrome.disabledForeground
        : (highlight
            ? Colors.white
            : ProcessModeOutlineChrome.actionOrange);
    // Vertically centered; nudge 10px left so long labels don't cover the icon.
    final iconTop =
        (height - ProcessModeOutlineChrome.iconSize) / 2;
    final iconLeft = iconTop - 10;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ProcessModeOutlineChrome.radius),
        color: highlight
            ? ProcessModeOutlineChrome.actionOrange
            : ProcessModeOutlineChrome.idleFill,
        border: Border.all(
          color: ProcessModeOutlineChrome.actionOrange,
          width: ProcessModeOutlineChrome.strokeWidth,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: ProcessModeOutlineChrome.labelSize,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
          Positioned(
            left: iconLeft,
            top: iconTop,
            width: ProcessModeOutlineChrome.iconSize,
            height: ProcessModeOutlineChrome.iconSize,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
              child: leading,
            ),
          ),
        ],
      ),
    );
  }
}
