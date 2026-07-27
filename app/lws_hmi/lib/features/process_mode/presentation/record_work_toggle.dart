import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';

/// Quick / Engineer Record Work checkbox row (lws-ui `CameraController`).
final class RecordWorkToggle extends StatefulWidget {
  const RecordWorkToggle({
    super.key,
    required this.deviceControl,
    this.compact = false,
    this.expand = false,
  });

  final DeviceControlController deviceControl;

  /// Quick Mode top-left: intrinsic width, smaller label.
  final bool compact;

  /// Engineer left panel: fill parent row height.
  final bool expand;

  @override
  State<RecordWorkToggle> createState() => _RecordWorkToggleState();
}

final class _RecordWorkToggleState extends State<RecordWorkToggle> {
  late final RecordWorkController _record = RecordWorkController(
    deviceControl: widget.deviceControl,
    onMessage: (message) {
      if (!mounted) {
        return;
      }
      ProcessModeToast.show(context, message);
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_record.start(AppScope.maybeOf(context)));
    });
  }

  @override
  void didUpdateWidget(covariant RecordWorkToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Device control is owned by the page and stays stable for the route.
  }

  @override
  void dispose() {
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _record,
      builder: (context, _) {
        final row = _RecordWorkRow(
          armed: _record.armed,
          enabled: _record.enabled,
          compact: widget.compact,
          onChanged: _record.enabled
              ? (value) => unawaited(_record.setArmed(value))
              : null,
        );
        if (widget.expand) {
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
