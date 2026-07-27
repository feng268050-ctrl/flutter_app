import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';

/// Quick / Engineer Record Work checkbox row (lws-ui `CameraController`).
///
/// The page owns [RecordWorkController] so exit paths can stop recording
/// without digging into private widget state.
final class RecordWorkToggle extends StatelessWidget {
  const RecordWorkToggle({
    super.key,
    required this.controller,
    this.compact = false,
    this.expand = false,
  });

  final RecordWorkController controller;

  /// Quick Mode top-left: intrinsic width, smaller label.
  final bool compact;

  /// Engineer left panel: fill parent row height.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final row = _RecordWorkRow(
          armed: controller.armed,
          enabled: controller.enabled,
          compact: compact,
          onChanged: controller.enabled
              ? (value) => unawaited(controller.setArmed(value))
              : null,
        );
        if (expand) {
          return SizedBox.expand(child: row);
        }
        return row;
      },
    );
  }
}

final class _RecordWorkRow extends StatelessWidget {
  const _RecordWorkRow({
    required this.armed,
    required this.enabled,
    required this.compact,
    required this.onChanged,
  });

  final bool armed;
  final bool enabled;
  final bool compact;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final labelSize = compact ? 16.0 : 22.0;
    return InkWell(
      onTap: enabled && onChanged != null
          ? () {
              CyberClickSoundRegistry.playClick();
              onChanged!(!armed);
            }
          : null,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          IgnorePointer(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: CyberCheckbox(
                value: armed,
                onChanged: enabled && onChanged != null ? (_) {} : null,
                clickSoundEnabled: false,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 12),
          Text(
            'Record Work',
            style: TextStyle(
              color: enabled ? Colors.white : const Color(0x66FFFFFF),
              fontSize: labelSize,
              fontWeight: FontWeight.w500,
              height: 1.0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
