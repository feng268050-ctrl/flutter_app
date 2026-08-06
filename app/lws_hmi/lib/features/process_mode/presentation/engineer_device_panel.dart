import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/record_work_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_frost_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_ramp_chart.dart';
import 'package:lws_hmi/features/process_mode/presentation/feed_hold_progress.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/record_work_toggle.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_scope.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// Engineer left device panel (lws-ui `engineer_continuous_device_controls`).
///
/// Wire Feed/Retract use [_EngineerWireActionButton]. Continuous welding is
/// the only process type with live wire controls.
final class EngineerDevicePanel extends StatefulWidget {
  const EngineerDevicePanel({
    super.key,
    required this.controller,
    required this.recordWork,
    required this.processType,
    required this.preset,
    this.onBeforeEnableLaser,
    this.onConfigureWorkSession,
  });

  final DeviceControlController controller;
  final RecordWorkController recordWork;
  final ProcessType processType;
  final ProcessPreset preset;

  /// Optional pre-enable hook (safety dialog + re-apply process). Return
  /// `false` to abort laser enable.
  final Future<bool> Function()? onBeforeEnableLaser;

  /// Captures the applied process context immediately before Laser Enable.
  final ValueChanged<ProcessPreset>? onConfigureWorkSession;

  /// Gap from Enable Laser to frost panel bottom.
  /// Shared with right-panel Reset/Save so button bottoms stay flush.
  static const panelBottomInset = 25.0;

  @override
  State<EngineerDevicePanel> createState() => _EngineerDevicePanelState();
}

final class _EngineerDevicePanelState extends State<EngineerDevicePanel> {
  bool _rampOpen = false;

  /// Fixed ramp accordion strip (header + divider).
  static const _rampHeaderHeight = 65.0;

  /// Gap from frost panel top to ramp header.
  static const _panelTopInset = 2.0;

  /// Shared gap: Retract↔Feed (horizontal only).
  static const _actionGap = 20.0;

  /// Engineer checkbox face — large tier.
  static const _checkboxSize = CyberDimens.checkboxLargeSize;

  /// Match right-panel parameter row height ([EngineerParameterForm] rows).
  static const _checkboxRowHeight = 86.0;

  /// Retract / Feed — CyberButton medium height (style/width unchanged).
  static const _wireButtonsHeight = CyberDimens.actionButtonMediumHeight;

  /// Enable Laser — CyberButton large height (style/width unchanged).
  static const _laserButtonHeight = CyberDimens.actionButtonLargeHeight;

  /// Top function-divider strip on last-three tabs (above Record Work).
  /// Height is the strip that holds the centered hairline, not empty padding.
  static const _topFunctionGapHeight = 26.0;

  bool get _showRamp =>
      widget.processType == ProcessType.continuousWelding ||
      widget.processType == ProcessType.spotWelding;

  /// Last three engineer tabs (Clean / Wide Clean / Cut) — no ramp strip.
  bool get _showTopFunctionDivider => !_showRamp;

  bool get _wireCapable => widget.processType == ProcessType.continuousWelding;

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
    final thresholdsController =
        AdvancedSettingsScope.maybeThresholdsOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (thresholdsController != null) thresholdsController,
      ]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        // lws-ui `isOpenLaser()` — session bit only, not emission feedback.
        final laserActive = widget.controller.laserSessionArmed;
        final thresholds = thresholdsController?.values ??
            const AdvancedSettingsThresholdValues();
        // Toast mutex only — do not dim peers for laser / non-wire / busy.
        return EngineerFrostPanel(
          key: const ValueKey('engineer-device-panel'),
          edge: EngineerFrostEdge.topLeftBottomRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              _panelTopInset,
              20,
              EngineerDevicePanel.panelBottomInset,
            ),
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
                          // Last 3 tabs: 26px strip for the top function divider.
                          if (_showTopFunctionDivider)
                            const SizedBox(
                              key: ValueKey('engineer-panel-top-divider'),
                              height: _topFunctionGapHeight,
                              child: Center(
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0x33FFFFFF),
                                ),
                              ),
                            ),
                          // Fixed 86px checkbox rows (same as right parameter rows).
                          SizedBox(
                            height: _checkboxRowHeight,
                            child: RecordWorkToggle(
                              key: const ValueKey(
                                  'engineer-panel-record-work'),
                              controller: widget.recordWork,
                              processType: widget.processType,
                              expand: true,
                              checkboxSize: _checkboxSize,
                            ),
                          ),
                          const Divider(
                              color: Color(0x33FFFFFF), height: 1),
                          SizedBox(
                            height: _checkboxRowHeight,
                            child: _CheckRow(
                              key: const ValueKey(
                                  'engineer-panel-manual-gas'),
                              label: l10n.manualGas,
                              value: widget.controller.manualGas,
                              enabled: true,
                              checkboxSize: _checkboxSize,
                              onChanged: (value) async {
                                if (widget.controller.busy) {
                                  _toast(
                                    context,
                                    LaserEnableBlockReason.busy
                                        .localizedMessage(l10n),
                                  );
                                  return;
                                }
                                if (laserActive) {
                                  _toast(
                                    context,
                                    DeviceControlFeedbackCopy.endOfWorkFirst(
                                      l10n,
                                    ),
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
                                        err.localizedMessage(l10n),
                                  );
                                  return;
                                }
                                _toast(
                                  context,
                                  value
                                      ? DeviceControlFeedbackCopy.manualGasOn(
                                          l10n,
                                        )
                                      : DeviceControlFeedbackCopy.manualGasOff(
                                          l10n,
                                        ),
                                );
                              },
                            ),
                          ),
                          const Divider(
                              color: Color(0x33FFFFFF), height: 1),
                          SizedBox(
                            height: _checkboxRowHeight,
                            child: _CheckRow(
                              key: const ValueKey(
                                  'engineer-panel-auto-wire'),
                              label: l10n.autoWireFeed,
                              value: widget.controller.autoWireFeed &&
                                  _wireCapable,
                              enabled: _wireCapable,
                              checkboxSize: _checkboxSize,
                              onChanged: (value) async {
                                if (!_wireCapable) {
                                  return;
                                }
                                if (widget.controller.busy) {
                                  _toast(
                                    context,
                                    LaserEnableBlockReason.busy
                                        .localizedMessage(l10n),
                                  );
                                  return;
                                }
                                if (laserActive) {
                                  _toast(
                                    context,
                                    DeviceControlFeedbackCopy.endOfWorkFirst(
                                      l10n,
                                    ),
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
                                        err.localizedMessage(l10n),
                                  );
                                  return;
                                }
                                _toast(
                                  context,
                                  value
                                      ? DeviceControlFeedbackCopy
                                          .autoWireFeedOn(l10n)
                                      : DeviceControlFeedbackCopy
                                          .autoWireFeedOff(l10n),
                                );
                              },
                            ),
                          ),
                          const Divider(
                              color: Color(0x33FFFFFF), height: 1),
                          // Equal flex above / below Retract·Feed.
                          const Spacer(),
                          SizedBox(
                            height: _wireButtonsHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _EngineerWireActionButton(
                                    key: const ValueKey(
                                        'engineer-panel-feed'),
                                    label: DeviceControlFeedbackCopy.feedLabel(
                                      l10n,
                                    ),
                                    icon: Icons.output,
                                    height: _wireButtonsHeight,
                                    enabled: _wireCapable,
                                    laserBlocked: laserActive,
                                    modeBlocked: false,
                                    retract: false,
                                    active: widget.controller.wireWork &&
                                        !widget.controller.wireRetracting,
                                    controller: widget.controller,
                                    onMessage: (message) =>
                                        _toast(context, message),
                                  ),
                                ),
                                const SizedBox(width: _actionGap),
                                Expanded(
                                  child: _EngineerWireActionButton(
                                    key: const ValueKey(
                                        'engineer-panel-retract'),
                                    label: l10n.retract,
                                    icon: Icons.output,
                                    height: _wireButtonsHeight,
                                    enabled: _wireCapable,
                                    laserBlocked: laserActive,
                                    modeBlocked: false,
                                    retract: true,
                                    active: widget.controller.wireWork &&
                                        widget.controller.wireRetracting,
                                    controller: widget.controller,
                                    onMessage: (message) =>
                                        _toast(context, message),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _EngineerDeviceActionButton(
                            key: const ValueKey('engineer-panel-laser'),
                            label: laserActive
                                ? l10n.endOfWork
                                : l10n.laserEnable,
                            icon: laserActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            height: _laserButtonHeight,
                            filled: true,
                            laserOn: laserActive,
                            enabled: true,
                            onHoldComplete: () async {
                              if (widget.controller.busy) {
                                _toast(
                                  context,
                                  LaserEnableBlockReason.busy
                                      .localizedMessage(l10n),
                                );
                                return;
                              }
                              if (widget.controller.manualGas) {
                                _toast(
                                  context,
                                  LaserEnableBlockReason.manualGasOn
                                      .localizedMessage(l10n),
                                );
                                return;
                              }
                              final before = widget.onBeforeEnableLaser;
                              if (before != null) {
                                final ok = await before();
                                if (!ok || !context.mounted) {
                                  return;
                                }
                              }
                              widget.onConfigureWorkSession
                                  ?.call(widget.preset);
                              final policy =
                                  AdvancedSettingsScope.maybeDangerousOf(
                                              context)
                                          ?.policySnapshot ??
                                      const LaserAlarmPolicySnapshot(
                                        keepLaserOnWhileAlarmed: false,
                                        allowWorkAfterCameraAlarm: false,
                                        allowWorkAfterGasAlarm: false,
                                        allowWorkAfterLensContamination: false,
                                        allowWorkAfterFeederAlarm: false,
                                      );
                              final err = await widget.controller.enableLaser(
                                warnAlarm: WarnAlarmScope.maybeOf(context),
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
                                        .tipForLaserEnableBlock(l10n, err),
                                  );
                                } else {
                                  _toast(
                                    context,
                                    err.localizedMessage(l10n),
                                  );
                                }
                              }
                            },
                            onPressed: laserActive
                                ? () async {
                                    final err =
                                        await widget.controller.disableLaser();
                                    if (err != null && context.mounted) {
                                      _toast(
                                        context,
                                        DeviceControlFeedbackCopy
                                            .messageForDisable(l10n, err),
                                      );
                                    }
                                  }
                                : null,
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
                            color: Theme.of(context).scaffoldBackgroundColor,
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
    this.checkboxSize = CyberDimens.checkboxLargeSize,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final double checkboxSize;

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
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              IgnorePointer(
                child: Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: CyberCheckbox(
                    value: value,
                    size: checkboxSize,
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
                  style: context.hmiTypography.sectionTitle.copyWith(
                    color: enabled ? Colors.white : const Color(0x66FFFFFF),
                    fontWeight: FontWeight.w500,
                    height: 1.0,
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
    extends State<_EngineerWireActionButton>
    with SingleTickerProviderStateMixin {
  late final ManualWireGesture _gesture = ManualWireGesture(
    controller: widget.controller,
    retract: widget.retract,
    isEnabled: () => widget.enabled,
    isActive: () => widget.active,
    onMessage: widget.onMessage,
    onVisualChanged: _onGestureVisual,
    l10n: () => AppLocalizations.of(context)!,
  );

  FeedHoldProgressController? _feedProgress;
  bool _wasLatched = false;

  @override
  void initState() {
    super.initState();
    if (!widget.retract) {
      _feedProgress = FeedHoldProgressController(
        vsync: this,
        onChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
        onFillCompleted: () {
          if (!mounted) {
            return;
          }
          _gesture.promoteContinuousFeedIfHolding();
        },
      );
    }
  }

  void _onGestureVisual() {
    if (!mounted) {
      return;
    }
    final progress = _feedProgress;
    if (progress != null) {
      final latched = _gesture.latched;
      if (latched && !_wasLatched) {
        progress.onLatched();
      } else if (!latched && _wasLatched) {
        progress.reset();
      }
      _wasLatched = latched;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _feedProgress?.dispose();
    _gesture.dispose();
    super.dispose();
  }

  void _pointerDown() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.controller.busy) {
      widget.onMessage(
        LaserEnableBlockReason.busy.localizedMessage(l10n),
      );
      return;
    }
    if (widget.laserBlocked) {
      widget.onMessage(DeviceControlFeedbackCopy.endOfWorkFirst(l10n));
      return;
    }
    if (widget.modeBlocked) {
      widget.onMessage(
        DeviceControlFeedbackCopy.wireUnavailableInMode(l10n),
      );
      return;
    }
    if (!widget.enabled) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    final progress = _feedProgress;
    if (progress != null && !_gesture.latched && !widget.active) {
      progress.onPressStart();
    }
    _gesture.pointerDown();
  }

  void _pointerUp() {
    if (widget.controller.busy ||
        widget.laserBlocked ||
        widget.modeBlocked) {
      return;
    }
    final wasLatched = _gesture.latched;
    _gesture.pointerUp();
    final progress = _feedProgress;
    if (progress == null || wasLatched || _gesture.latched) {
      return;
    }
    progress.onPressEndEarly();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const actionOrange = Color(0xFFF46E01);
    const idleFill = Color(0xFF2C1923);
    final latched = !widget.retract && _gesture.latched;
    final progress = _feedProgress;
    final filling = progress != null && progress.showsFill;
    final solidHighlight = widget.enabled &&
        (widget.retract
            ? (widget.active || _gesture.pressed || _gesture.holdingRun)
            : (latched ||
                (_gesture.pressed && !filling) ||
                (widget.active && !filling && !_gesture.pressed)));
    final onFill = solidHighlight || filling;
    final foreground = onFill ? Colors.white : actionOrange;
    final disabledForeground = const Color(0xFF7D3E2B);
    final labelSize = context.hmiTypography.settingsRowTitle.fontSize!;
    const iconSize = 26.0;
    final label = latched
        ? DeviceControlFeedbackCopy.continuousFeedLabel(l10n)
        : widget.label;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: label,
      child: Listener(
        onPointerDown: (_) => _pointerDown(),
        onPointerUp: (_) => _pointerUp(),
        onPointerCancel: (_) => _pointerUp(),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: solidHighlight ? actionOrange : idleFill,
              // Spot / Seam / Wide / Cutting: no outline when wire unavailable.
              border: widget.enabled
                  ? Border.all(
                      color: actionOrange,
                      width: 1.5,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (filling)
                    FeedHoldProgressFill(
                      progress: progress.value,
                      radius: 14,
                      color: actionOrange,
                    ),
                  if (latched) const FeedContinuousRipple(),
                  // Continuous Feed: label only. Else [gap][icon][gap][text][gap]
                  // so left inset equals icon↔label spacing; icon+text H-aligned.
                  // Text is never ellipsized — shrink icon/gaps first if needed.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final style = TextStyle(
                        color: widget.enabled
                            ? foreground
                            : disabledForeground,
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      );
                      if (latched) {
                        return Center(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            softWrap: false,
                            style: style,
                          ),
                        );
                      }
                      final painter = TextPainter(
                        text: TextSpan(text: label, style: style),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout();
                      final textW = painter.width;
                      var drawIcon = iconSize;
                      var gap = (constraints.maxWidth - drawIcon - textW) / 3;
                      if (gap < 0) {
                        // Keep full label; shrink icon, then gaps to zero.
                        drawIcon = (constraints.maxWidth - textW)
                            .clamp(0.0, iconSize);
                        gap = (constraints.maxWidth - drawIcon - textW) / 3;
                        if (gap < 0) {
                          gap = 0;
                          drawIcon = (constraints.maxWidth - textW)
                              .clamp(0.0, iconSize);
                        }
                      }
                      final row = Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: gap),
                          if (drawIcon > 0)
                            SizedBox(
                              width: drawIcon,
                              height: drawIcon,
                              child: Transform.flip(
                                flipX: widget.retract,
                                child: Icon(
                                  widget.icon,
                                  color: widget.enabled
                                      ? foreground
                                      : disabledForeground,
                                  size: drawIcon,
                                ),
                              ),
                            ),
                          SizedBox(width: gap),
                          Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: style,
                          ),
                          SizedBox(width: gap),
                        ],
                      );
                      // Scale down only if the panel is too narrow for full text.
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: row,
                      );
                    },
                  ),
                ],
              ),
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
    // Label scales with filled/outline; icons stay 34 (match Quick side ops).
    final typography = context.hmiTypography;
    final labelSize = widget.filled
        ? typography.sectionTitle.fontSize!
        : typography.supporting.fontSize!;
    const iconSize = 34.0;
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
                // Label centered; icon left inset = top/bottom inset.
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isVisuallyEnabled
                              ? foreground
                              : disabledForeground,
                          fontSize: labelSize,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ),
                    Positioned(
                      left: (widget.height - iconSize) / 2,
                      top: (widget.height - iconSize) / 2,
                      child: Icon(
                        widget.icon,
                        color: isVisuallyEnabled
                            ? foreground
                            : disabledForeground,
                        size: iconSize,
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
