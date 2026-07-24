import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';

/// Engineer left device panel (lws-ui `engineer_continuous_device_controls`).
///
/// Wire feed/retract stay stubbed until protocol is confirmed.
final class EngineerDevicePanel extends StatelessWidget {
  const EngineerDevicePanel({
    super.key,
    required this.controller,
    required this.processType,
  });

  final DeviceControlController controller;
  final ProcessType processType;

  bool get _wireEnabled => processType == ProcessType.continuousWelding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final laserActive = controller.laserEnable || controller.laserOn;
        return EngineerFrostPanel(
          key: const ValueKey('engineer-device-panel'),
          edge: EngineerFrostEdge.topLeftBottomRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _CheckRow(
                        label: 'Record Work',
                        value: false,
                        enabled: false,
                        onChanged: null,
                      ),
                      const Divider(color: Color(0x33FFFFFF), height: 1),
                      _CheckRow(
                        key: const ValueKey('engineer-panel-manual-gas'),
                        label: 'Manual Gas',
                        value: controller.manualGas,
                        enabled: !laserActive && !controller.busy,
                        onChanged: (value) async {
                          final err = await controller.setManualGas(value);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err.message)),
                            );
                          }
                        },
                      ),
                      const Divider(color: Color(0x33FFFFFF), height: 1),
                      _CheckRow(
                        key: const ValueKey('engineer-panel-auto-wire'),
                        label: 'Auto Wire Feed',
                        value: false,
                        enabled: false,
                        onChanged: null,
                        subtitle: _wireEnabled ? 'Protocol TBD' : null,
                      ),
                      const Divider(color: Color(0x33FFFFFF), height: 1),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: _EngineerDeviceActionButton(
                              key: const ValueKey('engineer-panel-retract'),
                              label: 'Retract',
                              icon: Icons.output,
                              height: 52,
                              enabled: false,
                              visualEnabled: true,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _EngineerDeviceActionButton(
                              key: const ValueKey('engineer-panel-feed'),
                              label: 'Feed',
                              icon: Icons.input,
                              height: 52,
                              enabled: false,
                              visualEnabled: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // lws-ui target geometry: a distinct two-tier action group.
                const SizedBox(height: 40),
                _EngineerDeviceActionButton(
                  key: const ValueKey('engineer-panel-laser'),
                  label: laserActive ? 'End Work' : 'Enable Laser',
                  icon: laserActive ? Icons.pause : Icons.ondemand_video,
                  height: 104,
                  filled: true,
                  laserOn: laserActive,
                  enabled: !(controller.busy || controller.manualGas),
                  onHoldComplete: () async {
                    final policy =
                        AdvancedSettingsScope.maybeDangerousOf(context)
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err.message)),
                      );
                    }
                  },
                  onPressed: laserActive
                      ? () async {
                          final err = await controller.disableLaser();
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err.message)),
                            );
                          }
                        }
                      : null,
                ),
                if (controller.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    controller.lastError!,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: InkWell(
        onTap: enabled && onChanged != null
            ? () {
                CyberClickSoundRegistry.playClick();
                onChanged!(!value);
              }
            : null,
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              color: value
                  ? ProcessModeTokens.tabCleanActive
                  : const Color(0x66FFFFFF),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled ? Colors.white : const Color(0x66FFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lws-ui continuous-weld device actions share a single control family:
/// outline actions for wire movement and a solid, safety-hold laser action.
final class _EngineerDeviceActionButton extends StatefulWidget {
  const _EngineerDeviceActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.height,
    this.enabled = true,
    this.visualEnabled,
    this.filled = false,
    this.laserOn = false,
    this.onPressed,
    this.onHoldComplete,
  });

  final String label;
  final IconData icon;
  final double height;
  final bool enabled;
  final bool? visualEnabled;
  final bool filled;
  final bool laserOn;
  final Future<void> Function()? onPressed;
  final Future<void> Function()? onHoldComplete;

  @override
  State<_EngineerDeviceActionButton> createState() =>
      _EngineerDeviceActionButtonState();
}

final class _EngineerDeviceActionButtonState
    extends State<_EngineerDeviceActionButton> {
  Timer? _holdTimer;
  DateTime? _pressStarted;
  double _progress = 0;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (!widget.enabled || widget.onHoldComplete == null) {
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
      final ratio = (elapsed.inMilliseconds / 300).clamp(0.0, 1.0);
      setState(() => _progress = ratio);
      if (ratio >= 1) {
        _holdTimer?.cancel();
        _holdTimer = null;
        _pressStarted = null;
        setState(() => _progress = 0);
        final onHoldComplete = widget.onHoldComplete;
        if (onHoldComplete != null) {
          await onHoldComplete();
        }
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
    const actionOrange = Color(0xFFF46E01);
    const activeOrange = Color(0xFFF37535);
    final isHoldAction = widget.onHoldComplete != null && !widget.laserOn;
    final canPress =
        widget.enabled && (widget.onPressed != null || isHoldAction);
    final isVisuallyEnabled = widget.visualEnabled ?? widget.enabled;
    final fillColor = widget.laserOn ? activeOrange : actionOrange;
    final foreground = widget.filled ? Colors.white : actionOrange;
    final disabledForeground =
        widget.filled ? const Color(0x99FFFFFF) : const Color(0xFF7D3E2B);
    return Semantics(
      button: true,
      enabled: canPress,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) {
          if (!canPress) {
            return;
          }
          CyberClickSoundRegistry.playClick();
          if (widget.onPressed != null) {
            unawaited(widget.onPressed!());
            return;
          }
          _startHold();
        },
        onPointerUp: (_) => _cancelHold(),
        onPointerCancel: (_) => _cancelHold(),
        child: Opacity(
          opacity: isVisuallyEnabled ? 1 : 0.55,
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.filled ? fillColor : const Color(0xFF2C1923),
              border: Border.all(
                color: widget.filled ? fillColor : actionOrange,
                width: 1.5,
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
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color:
                          isVisuallyEnabled ? foreground : disabledForeground,
                      size: widget.filled ? 38 : 32,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color:
                            isVisuallyEnabled ? foreground : disabledForeground,
                      fontSize: widget.filled ? 20 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
