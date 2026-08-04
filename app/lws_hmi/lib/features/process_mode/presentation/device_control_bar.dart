import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

/// Bottom device-control strip: manual gas + hold-to-enable laser + wire stubs.
///
/// Wire feed/retract are disabled until pulse/hold protocol is confirmed.
final class DeviceControlBar extends StatelessWidget {
  const DeviceControlBar({
    super.key,
    required this.controller,
    required this.processType,
  });

  final DeviceControlController controller;
  final ProcessType processType;

  bool get _showWireStub =>
      processType == ProcessType.continuousWelding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final accent = ProcessModeTokens.tabActiveColor(processType);
        // lws-ui `isOpenLaser()` — session bit only, not emission feedback.
        final laserActive = controller.laserSessionArmed;
        return Material(
          key: const ValueKey('device-control-bar'),
          color: const Color(0xFF0C0E24),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ManualGasSwitch(
                          enabled: !laserActive && !controller.busy,
                          value: controller.manualGas,
                          onChanged: (value) async {
                            final err = await controller.setManualGas(value);
                            if (err != null && context.mounted) {
                              _toast(context, err.message);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _LaserHoldButton(
                          accent: accent,
                          laserOn: laserActive,
                          busy: controller.busy || controller.manualGas,
                          onEnable: () async {
                            final policy = AdvancedSettingsScope
                                    .maybeDangerousOf(context)
                                    ?.policySnapshot ??
                                const LaserAlarmPolicySnapshot(
                                  keepLaserOnWhileAlarmed: false,
                                  allowWorkAfterCameraAlarm: false,
                                  allowWorkAfterGasAlarm: false,
                                  allowWorkAfterLensContamination: false,
                                  allowWorkAfterFeederAlarm: false,
                                );
                            final err = await controller.enableLaser(
                              warnAlarm: WarnAlarmScope.maybeOf(context),
                              policy: policy,
                            );
                            if (err != null && context.mounted) {
                              await _handleEnableBlock(
                                context,
                                err,
                                policy: policy,
                              );
                            }
                          },
                          onDisable: () async {
                            final err = await controller.disableLaser();
                            if (err != null && context.mounted) {
                              _toast(
                                context,
                                DeviceControlFeedbackCopy.messageForDisable(
                                  err,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      if (_showWireStub) ...[
                        const SizedBox(width: 12),
                        const Expanded(child: _WireFeedStub()),
                      ],
                    ],
                  ),
                  if (controller.lastError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      controller.lastError!,
                      key: const ValueKey('device-control-error'),
                      style: const TextStyle(
                        color: Color(0xFFFF8A80),
                        fontSize: AppTypography.microSize,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleEnableBlock(
    BuildContext context,
    LaserEnableBlockReason err, {
    required LaserAlarmPolicySnapshot policy,
  }) async {
    if (err == LaserEnableBlockReason.alarmBlocked) {
      final warn = WarnAlarmScope.maybeOf(context);
      if (warn != null) {
        await warn.presentLaserEnableBlock(policy: policy);
        return;
      }
    }
    if (DeviceControlFeedbackCopy.isSafetyTipBlock(err)) {
      await OperationFailedDialogHost.show(
        context,
        message: DeviceControlFeedbackCopy.tipForLaserEnableBlock(err),
      );
      return;
    }
    _toast(context, err.message);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

final class _ManualGasSwitch extends StatelessWidget {
  const _ManualGasSwitch({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const ValueKey('device-control-manual-gas'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: const Text(
        'Manual Gas',
        style: TextStyle(color: Colors.white, fontSize: AppTypography.captionSize),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeColor: ProcessModeTokens.tabCleanActive,
    );
  }
}

/// Flutter hold-to-enable laser (replaces Android trapezoid long-press).
final class _LaserHoldButton extends StatefulWidget {
  const _LaserHoldButton({
    required this.accent,
    required this.laserOn,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
  });

  final Color accent;
  final bool laserOn;
  final bool busy;
  final Future<void> Function() onEnable;
  final Future<void> Function() onDisable;

  @override
  State<_LaserHoldButton> createState() => _LaserHoldButtonState();
}

final class _LaserHoldButtonState extends State<_LaserHoldButton> {
  Timer? _holdTimer;
  DateTime? _pressStarted;
  double _progress = 0;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (widget.busy || widget.laserOn) {
      return;
    }
    _pressStarted = DateTime.now();
    _progress = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (_) async {
      final started = _pressStarted;
      if (started == null) {
        return;
      }
      final elapsed = DateTime.now().difference(started);
      final ratio = (elapsed.inMilliseconds /
              DeviceControlTiming.laserHoldToEnable.inMilliseconds)
          .clamp(0.0, 1.0);
      setState(() => _progress = ratio);
      if (ratio >= 1) {
        _holdTimer?.cancel();
        _holdTimer = null;
        _pressStarted = null;
        setState(() => _progress = 0);
        await widget.onEnable();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pressStarted = null;
    if (_progress != 0) {
      setState(() => _progress = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.laserOn ? 'Laser Off' : 'Hold to Enable Laser';
    return Listener(
      key: const ValueKey('device-control-laser'),
      onPointerDown: (_) {
        if (widget.laserOn) {
          unawaited(widget.onDisable());
          return;
        }
        _startHold();
      },
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: AnimatedOpacity(
        opacity: widget.busy ? 0.45 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.accent.withOpacity(0.8), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.accent.withOpacity(widget.laserOn ? 0.55 : 0.15),
                widget.accent.withOpacity(widget.laserOn ? 0.35 : 0.05),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_progress > 0)
                FractionallySizedBox(
                  widthFactor: _progress,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.accent.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTypography.supportingSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wire feed/retract placeholder until protocol is confirmed on device.
final class _WireFeedStub extends StatelessWidget {
  const _WireFeedStub();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: Column(
        key: const ValueKey('device-control-wire-stub'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: null,
            child: const Text('Feed'),
          ),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: null,
            child: const Text('Retract'),
          ),
          const Text(
            'Wire: protocol TBD',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: AppTypography.microSize),
          ),
        ],
      ),
    );
  }
}
