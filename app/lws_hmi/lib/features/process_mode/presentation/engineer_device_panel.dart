import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_ramp_chart.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/record_work_toggle.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';

/// Engineer left device panel (lws-ui `engineer_continuous_device_controls`).
///
/// Wire Feed/Retract share Quick's [ManualWireGesture] protocol. Continuous
/// welding is the only process type with live wire controls.
final class EngineerDevicePanel extends StatefulWidget {
  const EngineerDevicePanel({
    super.key,
    required this.controller,
    required this.recordWork,
    required this.processType,
    required this.preset,
    this.onBeforeEnableLaser,
  });

  final DeviceControlController controller;
  final RecordWorkController recordWork;
  final ProcessType processType;
  final ProcessPreset preset;

  /// Optional pre-enable hook (safety dialog + re-apply process). Return
  /// `false` to abort laser enable.
  final Future<bool> Function()? onBeforeEnableLaser;

  @override
  State<EngineerDevicePanel> createState() => _EngineerDevicePanelState();
}

final class _EngineerDevicePanelState extends State<EngineerDevicePanel> {
  bool _rampOpen = false;

  /// Fixed ramp accordion strip (header + divider).
  static const _rampHeaderHeight = 50.0;

  /// Gap from frost panel top to ramp header.
  static const _panelTopInset = 2.0;

  /// Shared gap: Retract↔Feed, Feed/Retract↔Laser, checkboxes↔Retract/Feed.
  static const _actionGap = 20.0;

  /// Retract + Feed + Enable Laser block (includes gap between rows).
  static const _functionButtonsHeight = 120.0;
  static const _wireButtonsHeight = 45.0;
  static const _laserButtonHeight =
      _functionButtonsHeight - _wireButtonsHeight - _actionGap;

  bool get _showRamp =>
      widget.processType == ProcessType.continuousWelding ||
      widget.processType == ProcessType.spotWelding;

  bool get _wireCapable =>
      widget.processType == ProcessType.continuousWelding;

  @override
  void didUpdateWidget(covariant EngineerDevicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.processType != widget.processType) {
      _rampOpen = false;
    }
  }

  void _toast(BuildContext context, String message) {
    ProcessModeToast.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        // lws-ui `isOpenLaser()` — session bit only, not emission feedback.
        final laserActive = widget.controller.laserSessionArmed;
        final thresholds =
            AdvancedSettingsScope.maybeThresholdsOf(context)?.values ??
                const AdvancedSettingsThresholdValues();
        // Toast mutex only — do not dim peers for laser / non-wire / busy.
        return EngineerFrostPanel(
          key: const ValueKey('engineer-device-panel'),
          edge: EngineerFrostEdge.topLeftBottomRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, _panelTopInset, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showRamp)
                  SizedBox(
                    height: _rampHeaderHeight,
                    child: EngineerRampAccordionHeader(
                      expanded: _rampOpen,
                      onToggle: () => setState(() => _rampOpen = !_rampOpen),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: RecordWorkToggle(
                                    key: const ValueKey(
                                        'engineer-panel-record-work'),
                                    controller: widget.recordWork,
                                    expand: true,
                                  ),
                                ),
                                const Divider(
                                    color: Color(0x33FFFFFF), height: 1),
                                Expanded(
                                  child: _CheckRow(
                                    key: const ValueKey(
                                        'engineer-panel-manual-gas'),
                                    label: 'Manual Gas',
                                    value: widget.controller.manualGas,
                                    enabled: true,
                                    onChanged: (value) async {
                                      if (widget.controller.busy) {
                                        _toast(
                                          context,
                                          LaserEnableBlockReason.busy.message,
                                        );
                                        return;
                                      }
                                      if (laserActive) {
                                        _toast(
                                          context,
                                          DeviceControlFeedbackCopy
                                              .endOfWorkFirst,
                                        );
                                        return;
                                      }
                                      final err = await widget.controller
                                          .setManualGas(value);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      if (err != null) {
                                        _toast(
                                          context,
                                          widget.controller.lastError ??
                                              err.message,
                                        );
                                        return;
                                      }
                                      _toast(
                                        context,
                                        value
                                            ? DeviceControlFeedbackCopy
                                                .manualGasOn
                                            : DeviceControlFeedbackCopy
                                                .manualGasOff,
                                      );
                                    },
                                  ),
                                ),
                                const Divider(
                                    color: Color(0x33FFFFFF), height: 1),
                                Expanded(
                                  child: _CheckRow(
                                    key: const ValueKey(
                                        'engineer-panel-auto-wire'),
                                    label: 'Auto Wire Feed',
                                    value: widget.controller.autoWireFeed &&
                                        _wireCapable,
                                    enabled: true,
                                    onChanged: (value) async {
                                      if (widget.controller.busy) {
                                        _toast(
                                          context,
                                          LaserEnableBlockReason.busy.message,
                                        );
                                        return;
                                      }
                                      if (laserActive) {
                                        _toast(
                                          context,
                                          DeviceControlFeedbackCopy
                                              .endOfWorkFirst,
                                        );
                                        return;
                                      }
                                      if (!_wireCapable) {
                                        _toast(
                                          context,
                                          DeviceControlFeedbackCopy
                                              .wireUnavailableInMode,
                                        );
                                        return;
                                      }
                                      final err = await widget.controller
                                          .setAutoWireFeed(value);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      if (err != null) {
                                        _toast(
                                          context,
                                          widget.controller.lastError ??
                                              err.message,
                                        );
                                        return;
                                      }
                                      _toast(
                                        context,
                                        value
                                            ? DeviceControlFeedbackCopy
                                                .autoWireFeedOn
                                            : DeviceControlFeedbackCopy
                                                .autoWireFeedOff,
                                      );
                                    },
                                  ),
                                ),
                                const Divider(
                                    color: Color(0x33FFFFFF), height: 1),
                              ],
                            ),
                          ),
                          const SizedBox(height: _actionGap),
                          SizedBox(
                            height: _functionButtonsHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: _wireButtonsHeight,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _EngineerWireActionButton(
                                          key: const ValueKey(
                                              'engineer-panel-retract'),
                                          label: 'Retract',
                                          icon: Icons.output,
                                          height: _wireButtonsHeight,
                                          enabled: true,
                                          laserBlocked: laserActive,
                                          modeBlocked: !_wireCapable,
                                          retract: true,
                                          active: widget.controller.wireWork &&
                                              widget.controller.wireRetracting,
                                          controller: widget.controller,
                                          onMessage: (message) =>
                                              _toast(context, message),
                                        ),
                                      ),
                                      const SizedBox(width: _actionGap),
                                      Expanded(
                                        child: _EngineerWireActionButton(
                                          key: const ValueKey(
                                              'engineer-panel-feed'),
                                          label: 'Feed',
                                          icon: Icons.input,
                                          height: _wireButtonsHeight,
                                          enabled: true,
                                          laserBlocked: laserActive,
                                          modeBlocked: !_wireCapable,
                                          retract: false,
                                          active: widget.controller.wireWork &&
                                              !widget.controller.wireRetracting,
                                          controller: widget.controller,
                                          onMessage: (message) =>
                                              _toast(context, message),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: _actionGap),
                                _EngineerDeviceActionButton(
                                  key: const ValueKey('engineer-panel-laser'),
                                  label: laserActive
                                      ? 'End Work'
                                      : 'Enable Laser',
                                  icon: laserActive
                                      ? Icons.pause
                                      : Icons.ondemand_video,
                                  height: _laserButtonHeight,
                                  filled: true,
                                  laserOn: laserActive,
                                  enabled: true,
                                  onHoldComplete: () async {
                                    if (widget.controller.busy) {
                                      _toast(
                                        context,
                                        LaserEnableBlockReason.busy.message,
                                      );
                                      return;
                                    }
                                    if (widget.controller.manualGas) {
                                      _toast(
                                        context,
                                        LaserEnableBlockReason
                                            .manualGasOn.message,
                                      );
                                      return;
                                    }
                                    final before =
                                        widget.onBeforeEnableLaser;
                                    if (before != null) {
                                      final ok = await before();
                                      if (!ok || !context.mounted) {
                                        return;
                                      }
                                    }
                                    final policy = AdvancedSettingsScope
                                                .maybeDangerousOf(context)
                                            ?.policySnapshot ??
                                        const LaserAlarmPolicySnapshot(
                                          keepLaserOnWhileAlarmed: false,
                                          allowWorkAfterCameraAlarm: false,
                                          allowWorkAfterGasAlarm: false,
                                          allowWorkAfterLensContamination:
                                              false,
                                          allowWorkAfterFeederAlarm: false,
                                        );
                                    final err =
                                        await widget.controller.enableLaser(
                                      warnAlarm:
                                          WarnAlarmScope.maybeOf(context),
                                      policy: policy,
                                    );
                                    if (err != null && context.mounted) {
                                      if (err ==
                                          LaserEnableBlockReason.alarmBlocked) {
                                        final warn =
                                            WarnAlarmScope.maybeOf(context);
                                        if (warn != null) {
                                          await warn.presentLaserEnableBlock(
                                            policy: policy,
                                          );
                                        }
                                      } else if (DeviceControlFeedbackCopy
                                          .isSafetyTipBlock(err)) {
                                        await OperationFailedDialogHost.show(
                                          context,
                                          message: DeviceControlFeedbackCopy
                                              .tipForLaserEnableBlock(err),
                                        );
                                      } else {
                                        _toast(context, err.message);
                                      }
                                    }
                                  },
                                  onPressed: laserActive
                                      ? () async {
                                          final err = await widget.controller
                                              .disableLaser();
                                          if (err != null && context.mounted) {
                                            _toast(
                                              context,
                                              DeviceControlFeedbackCopy
                                                  .messageForDisable(err),
                                            );
                                          }
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Cover checkboxes + Retract/Feed; leave Enable Laser.
                      if (_showRamp && _rampOpen)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: _laserButtonHeight,
                          child: ColoredBox(
                            color: ProcessModeTokens.background,
                            child: EngineerRampChart(
                              processType: widget.processType,
                              preset: widget.preset,
                              startPower: thresholds.laserStartPower,
                              endPower: thresholds.laserEndPower,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: InkWell(
        onTap: enabled && onChanged != null
            ? () {
                CyberClickSoundRegistry.playClick();
                onChanged!(!value);
              }
            : null,
        child: Row(
          children: [
            IgnorePointer(
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: CyberCheckbox(
                  value: value,
                  // Visual only — row InkWell owns the tap.
                  onChanged: enabled && onChanged != null ? (_) {} : null,
                  clickSoundEnabled: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : const Color(0x66FFFFFF),
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wire Feed/Retract with [ManualWireGesture], Engineer outline chrome.
final class _EngineerWireActionButton extends StatefulWidget {
  const _EngineerWireActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.height,
    required this.enabled,
    required this.laserBlocked,
    required this.modeBlocked,
    required this.retract,
    required this.active,
    required this.controller,
    required this.onMessage,
  });

  final String label;
  final IconData icon;
  final double height;
  final bool enabled;
  final bool laserBlocked;
  final bool modeBlocked;
  final bool retract;
  final bool active;
  final DeviceControlController controller;
  final ValueChanged<String> onMessage;

  @override
  State<_EngineerWireActionButton> createState() =>
      _EngineerWireActionButtonState();
}

final class _EngineerWireActionButtonState
    extends State<_EngineerWireActionButton> {
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
    const actionOrange = Color(0xFFF46E01);
    final highlight = widget.enabled && (widget.active || _gesture.pressed);
    final foreground = highlight ? Colors.white : actionOrange;
    final disabledForeground = const Color(0xFF7D3E2B);
    const labelSize = 16.0;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) {
          if (widget.controller.busy) {
            widget.onMessage(LaserEnableBlockReason.busy.message);
            return;
          }
          if (widget.laserBlocked) {
            widget.onMessage(DeviceControlFeedbackCopy.endOfWorkFirst);
            return;
          }
          if (widget.modeBlocked) {
            widget.onMessage(DeviceControlFeedbackCopy.wireUnavailableInMode);
            return;
          }
          if (!widget.enabled) {
            return;
          }
          CyberClickSoundRegistry.playClick();
          _gesture.pointerDown();
        },
        onPointerUp: (_) {
          if (widget.controller.busy ||
              widget.laserBlocked ||
              widget.modeBlocked) {
            return;
          }
          _gesture.pointerUp();
        },
        onPointerCancel: (_) {
          if (widget.controller.busy ||
              widget.laserBlocked ||
              widget.modeBlocked) {
            return;
          }
          _gesture.pointerUp();
        },
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: highlight ? actionOrange : const Color(0xFF2C1923),
              border: Border.all(
                color: actionOrange,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: widget.enabled ? foreground : disabledForeground,
                  size: labelSize,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.enabled ? foreground : disabledForeground,
                    fontSize: labelSize,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
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
    // Icon height matches label font size (wire smaller; laser larger).
    final labelSize = widget.filled ? 22.0 : 16.0;
    final iconSize = labelSize;
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
                      size: iconSize,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color:
                            isVisuallyEnabled ? foreground : disabledForeground,
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
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
