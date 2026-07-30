import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Quick / Engineer Record Work checkbox row (lws-ui `CameraController`).
///
/// The page owns [RecordWorkController] so exit paths can stop recording
/// without digging into private widget state.
final class RecordWorkToggle extends StatelessWidget {
  const RecordWorkToggle({
    super.key,
    required this.controller,
    required this.processType,
    this.compact = false,
    this.expand = false,
  });

  final RecordWorkController controller;
  final ProcessType processType;

  /// Quick Mode top-left: intrinsic width, smaller label.
  final bool compact;

  /// Engineer left panel: fill parent row height.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final label =
        AppLocalizations.of(context)?.recordWorkLabel ?? 'Record Work';
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final row = _RecordWorkRow(
          armed: controller.armed,
          enabled: controller.enabled,
          compact: compact,
          label: label,
          recordingStartedAt: controller.recordingStartedAt,
          timerColor: ProcessModeTokens.tabActiveColor(processType),
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
    required this.label,
    required this.recordingStartedAt,
    required this.timerColor,
    required this.onChanged,
  });

  final bool armed;
  final bool enabled;
  final bool compact;
  final String label;
  final DateTime? recordingStartedAt;
  final Color timerColor;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final labelSize =
        compact ? ProcessModeDimens.quickTopChromeLabelSize : 22.0;
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
            label,
            style: TextStyle(
              color: enabled ? Colors.white : const Color(0x66FFFFFF),
              fontSize: labelSize,
              fontWeight: FontWeight.w500,
              height: 1.0,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(width: compact ? 10 : 16),
          _RecordWorkElapsed(
            startedAt: recordingStartedAt,
            color: timerColor,
          ),
        ],
      ),
    );
  }
}

/// Flutter-owned elapsed clock for the active Record Work MP4.
final class _RecordWorkElapsed extends StatefulWidget {
  const _RecordWorkElapsed({
    required this.startedAt,
    required this.color,
  });

  final DateTime? startedAt;
  final Color color;

  @override
  State<_RecordWorkElapsed> createState() => _RecordWorkElapsedState();
}

final class _RecordWorkElapsedState extends State<_RecordWorkElapsed> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _RecordWorkElapsed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _now = DateTime.now();
      _syncTicker();
    }
  }

  void _syncTicker() {
    _tick?.cancel();
    _tick = null;
    if (widget.startedAt == null) {
      return;
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startedAt = widget.startedAt;
    if (startedAt == null) {
      return const SizedBox.shrink();
    }
    final difference = _now.difference(startedAt);
    final elapsed = difference.isNegative ? Duration.zero : difference;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      key: const ValueKey('record-work-elapsed'),
      style: TextStyle(
        color: widget.color,
        fontSize: 18,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1,
      ),
    );
  }
}
