import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/key_switch_off_prompt.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

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
        final l10n = AppLocalizations.of(context)!;
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
                          l10n: l10n,
                          enabled: !laserActive && !controller.busy,
                          value: controller.manualGas,
                          onChanged: (value) async {
                            final err = await controller.setManualGas(value);
                            if (err != null && context.mounted) {
                              _toast(context, err.localizedMessage(l10n));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _LaserHoldButton(
                          l10n: l10n,
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
                                  l10n,
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
                      style: context.hmiTypography.technicalMeta.copyWith(
                        color: const Color(0xFFFF8A80),
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
    final l10n = AppLocalizations.of(context)!;
    if (err == LaserEnableBlockReason.alarmBlocked) {
      final warn = WarnAlarmScope.maybeOf(context);
      if (warn != null) {
        await warn.presentLaserEnableBlock(policy: policy);
        return;
      }
    }
    if (err == LaserEnableBlockReason.keySwitchOff) {
      await KeySwitchOffPrompt.presentLaserEnableKeyOffBlock(
        context,
        miscAlarmEnabled:
            MiscSettingsScope.maybeOf(context)?.showKeySwitchAlarm ?? false,
        services: AppScope.maybeOf(context),
      );
      return;
    }
    if (DeviceControlFeedbackCopy.isSafetyTipBlock(err)) {
      await OperationFailedDialogHost.show(
        context,
        message: DeviceControlFeedbackCopy.tipForLaserEnableBlock(l10n, err),
      );
      return;
    }
    _toast(context, err.localizedMessage(l10n));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

final class _ManualGasSwitch extends StatelessWidget {
  const _ManualGasSwitch({
    required this.l10n,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('device-control-manual-gas'),
      children: [
        Expanded(
          child: Text(
            l10n.manualGas,
            style: context.hmiTypography.caption.copyWith(color: Colors.white),
          ),
        ),
        CyberSwitch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// Flutter hold-to-enable laser (replaces Android trapezoid long-press).
final class _LaserHoldButton extends StatefulWidget {
  const _LaserHoldButton({
    required this.l10n,
    required this.accent,
    required this.laserOn,
    required this.busy,
    required this.onEnable,
    required this.onDisable,
  });

  final AppLocalizations l10n;
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
    final label =
        widget.laserOn ? widget.l10n.laserOff : widget.l10n.holdToEnableLaser;
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
                  style: context.hmiTypography.supporting.copyWith(
                    color: Colors.white,
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
    final l10n = AppLocalizations.of(context)!;
    return Opacity(
      opacity: 0.4,
      child: Column(
        key: const ValueKey('device-control-wire-stub'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: null,
            child: Text(DeviceControlFeedbackCopy.feedLabel(l10n)),
          ),
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: null,
            child: Text(l10n.retract),
          ),
          Text(
            'Wire: protocol TBD',
            textAlign: TextAlign.center,
            style: context.hmiTypography.technicalMeta.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
