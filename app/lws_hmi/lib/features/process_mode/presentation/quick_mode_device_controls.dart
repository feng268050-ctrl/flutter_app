import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_button.dart';

/// Quick-mode bottom composition: left/right side ops + center trapezoid.
///
/// Side groups mirror lws-ui `left_bottom_btn_group` / `right_bottom_btn_group`
/// and stay separate from [QuickModeLaserButton].
final class QuickModeDeviceControls extends StatelessWidget {
  const QuickModeDeviceControls({
    super.key,
    required this.controller,
    required this.processType,
    required this.laserPreflight,
    required this.onEnableConfirmed,
    required this.onDisable,
  });

  final DeviceControlController controller;
  final ProcessType processType;
  final String? Function() laserPreflight;
  final Future<void> Function() onEnableConfirmed;
  final Future<void> Function() onDisable;

  /// Continuous welding is the only Quick mode with wire-feed capability.
  bool get _wireCapable => processType == ProcessType.continuousWelding;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final laserOpen = controller.laserEnable || controller.laserOn;
        final scale =
            ProcessModeDimens.dashboardScaleFor(MediaQuery.sizeOf(context));
        return SizedBox.expand(
          key: const ValueKey('device-control-bar'),
          child: Stack(
            children: [
              if (!laserOpen)
                Positioned(
                  left: ProcessModeDimens.quickSideButtonInset * scale,
                  bottom: ProcessModeDimens.quickSideButtonBottom * scale,
                  width: ProcessModeDimens.quickSideButtonWidth,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _QuickSideToggle(
                          key: const ValueKey('device-control-manual-gas'),
                          processType: processType,
                          iconAsset: ProcessModeAssets.manualGasIcon,
                          disabledIconAsset: ProcessModeAssets.manualGasIcon,
                          label: 'Manual Gas',
                          selected: controller.manualGas,
                          enabled: !controller.busy,
                          onToggle: () => _toggleManualGas(context),
                        ),
                        SizedBox(
                          height: ProcessModeDimens.quickSideOpGapAboveDivider,
                        ),
                        _QuickSideDivider(processType: processType),
                        SizedBox(
                          height: ProcessModeDimens.quickSideOpGapBelowDivider,
                        ),
                        _QuickSideToggle(
                          key: const ValueKey('device-control-auto-wire-feed'),
                          processType: processType,
                          iconAsset: ProcessModeAssets.autoWireFeedOnIcon,
                          disabledIconAsset:
                              ProcessModeAssets.autoWireFeedOffIcon,
                          label: 'Auto Wire Feed',
                          selected: controller.autoWireFeed && _wireCapable,
                          enabled: _wireCapable && !controller.busy,
                          onToggle: () => _toggleAutoWire(context),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!laserOpen)
                Positioned(
                  right: ProcessModeDimens.quickSideButtonInset * scale,
                  bottom: ProcessModeDimens.quickSideButtonBottom * scale,
                  width: ProcessModeDimens.quickSideButtonWidth,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ManualWireButton(
                          key: const ValueKey('device-control-feed'),
                          processType: processType,
                          label: DeviceControlFeedbackCopy.feedLabel,
                          iconAsset: ProcessModeAssets.feedIcon,
                          disabledIconAsset: ProcessModeAssets.feedIcon,
                          busy: controller.busy,
                          enabled: _wireCapable && !controller.busy,
                          retract: false,
                          active:
                              controller.wireWork && !controller.wireRetracting,
                          controller: controller,
                          onMessage: (message) => _toast(context, message),
                        ),
                        SizedBox(
                          height: ProcessModeDimens.quickSideOpGapAboveDivider,
                        ),
                        _QuickSideDivider(processType: processType),
                        SizedBox(
                          height: ProcessModeDimens.quickSideOpGapBelowDivider,
                        ),
                        _ManualWireButton(
                          key: const ValueKey('device-control-retract'),
                          processType: processType,
                          label: 'Retract',
                          iconAsset: ProcessModeAssets.retractOnIcon,
                          disabledIconAsset: ProcessModeAssets.retractOffIcon,
                          busy: controller.busy,
                          enabled: _wireCapable && !controller.busy,
                          retract: true,
                          active:
                              controller.wireWork && controller.wireRetracting,
                          controller: controller,
                          onMessage: (message) => _toast(context, message),
                        ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: QuickModeLaserButton(
                  processType: processType,
                  laserOpen: laserOpen,
                  busy: controller.busy,
                  preflight: laserPreflight,
                  onEnableConfirmed: onEnableConfirmed,
                  onDisable: onDisable,
                  onBlocked: (message) => _toast(context, message),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleManualGas(BuildContext context) async {
    final enabling = !controller.manualGas;
    final error = await controller.setManualGas(enabling);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _toast(
        context,
        controller.lastError ?? error.message,
      );
      return;
    }
    _toast(
      context,
      enabling
          ? DeviceControlFeedbackCopy.manualGasOn
          : DeviceControlFeedbackCopy.manualGasOff,
    );
  }

  Future<void> _toggleAutoWire(BuildContext context) async {
    final enabling = !controller.autoWireFeed;
    final error = await controller.setAutoWireFeed(enabling);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _toast(
        context,
        controller.lastError ?? error.message,
      );
      return;
    }
    _toast(
      context,
      enabling
          ? DeviceControlFeedbackCopy.autoWireFeedOn
          : DeviceControlFeedbackCopy.autoWireFeedOff,
    );
  }

  void _toast(BuildContext context, String message) {
    ProcessModeToast.show(context, message);
  }
}

/// Mode-colored horizontal separator (transparent → accent → transparent).
final class _QuickSideDivider extends StatelessWidget {
  const _QuickSideDivider({required this.processType});

  final ProcessType processType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProcessModeDimens.quickSideOpDividerHeight,
      width: double.infinity,
      child: Center(
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: ProcessModeTokens.sideOperationDivider(processType),
          ),
        ),
      ),
    );
  }
}

/// Toggle row: icon + label, metal-sheen highlight when selected or pressed.
final class _QuickSideToggle extends StatefulWidget {
  const _QuickSideToggle({
    super.key,
    required this.processType,
    required this.iconAsset,
    required this.disabledIconAsset,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final ProcessType processType;
  final String iconAsset;
  final String disabledIconAsset;
  final String label;
  final bool selected;
  final bool enabled;
  final Future<void> Function() onToggle;

  @override
  State<_QuickSideToggle> createState() => _QuickSideToggleState();
}

final class _QuickSideToggleState extends State<_QuickSideToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.enabled && (widget.selected || _pressed);
    final fg =
        widget.enabled ? Colors.white : ProcessModeTokens.sideOperationDisabled;

    return Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? () => unawaited(widget.onToggle()) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: ProcessModeDimens.quickSideButtonWidth,
          padding: const EdgeInsets.symmetric(
            vertical: ProcessModeDimens.quickSideOpVerticalPadding,
          ),
          decoration: BoxDecoration(
            gradient: highlight
                ? ProcessModeTokens.sideOperationHighlight(widget.processType)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                widget.enabled ? widget.iconAsset : widget.disabledIconAsset,
                width: ProcessModeDimens.quickSideOpIconSize,
                height: ProcessModeDimens.quickSideOpIconSize,
                color: widget.enabled ? null : fg,
                colorBlendMode: widget.enabled ? null : BlendMode.srcIn,
              ),
              const SizedBox(width: ProcessModeDimens.quickSideOpIconGap),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: ProcessModeDimens.quickSideOpLabelSize,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
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

/// lws-ui parity: short press is a 500ms pulse; Feed held for 3s latches
/// until tapped again; Retract only runs while the pointer remains pressed.
///
/// Feed also shows `feed_sub_hold_hint`, swaps to Continuous Feed when latched,
/// and breathes a GradientButton-style accent fill while holding / latched.
final class _ManualWireButton extends StatefulWidget {
  const _ManualWireButton({
    super.key,
    required this.processType,
    required this.label,
    required this.iconAsset,
    required this.disabledIconAsset,
    required this.busy,
    required this.enabled,
    required this.retract,
    required this.active,
    required this.controller,
    required this.onMessage,
  });

  final ProcessType processType;
  final String label;
  final String iconAsset;
  final String disabledIconAsset;
  final bool busy;
  final bool enabled;
  final bool retract;
  final bool active;
  final DeviceControlController controller;
  final ValueChanged<String> onMessage;

  @override
  State<_ManualWireButton> createState() => _ManualWireButtonState();
}

final class _ManualWireButtonState extends State<_ManualWireButton>
    with TickerProviderStateMixin {
  late final ManualWireGesture _gesture = ManualWireGesture(
    controller: widget.controller,
    retract: widget.retract,
    isEnabled: () => widget.enabled,
    isActive: () => widget.active,
    onMessage: widget.onMessage,
    onVisualChanged: () {
      if (mounted) {
        setState(() {});
        _syncHoldProgress();
      }
    },
  );

  /// Determinate 0→1 over 3s while pressed (lws-ui hold-to-latch cue).
  late final AnimationController _holdProgress = AnimationController(
    vsync: this,
    duration: DeviceControlTiming.wireFeedLatchDelay,
  );

  /// Soft breath after latch (GradientButton continuous feed).
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  bool _breathing = false;

  @override
  void dispose() {
    _holdProgress.dispose();
    _breath.dispose();
    _gesture.dispose();
    super.dispose();
  }

  void _syncHoldProgress() {
    if (widget.retract) {
      return;
    }
    final holding = widget.enabled && _gesture.pressed && !_gesture.latched;
    final latched = widget.enabled && _gesture.latched;

    if (holding) {
      if (!_holdProgress.isAnimating && _holdProgress.value < 1) {
        unawaited(_holdProgress.forward(from: _holdProgress.value));
      }
      if (_breathing) {
        _breathing = false;
        _breath.stop();
        _breath.value = 0;
      }
    } else if (latched) {
      _holdProgress.value = 1;
      if (!_breathing) {
        _breathing = true;
        unawaited(_breath.repeat(reverse: true));
      }
    } else {
      if (_holdProgress.isAnimating || _holdProgress.value != 0) {
        _holdProgress.stop();
        _holdProgress.value = 0;
      }
      if (_breathing) {
        _breathing = false;
        _breath.stop();
        _breath.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFeed = !widget.retract;
    final latched = isFeed && _gesture.latched;
    final showProgress = isFeed &&
        widget.enabled &&
        (_gesture.pressed || latched || _holdProgress.value > 0);
    final retractHighlight =
        !isFeed && widget.enabled && (widget.active || _gesture.pressed);
    final fg =
        widget.enabled ? Colors.white : ProcessModeTokens.sideOperationDisabled;
    final label = latched
        ? DeviceControlFeedbackCopy.continuousFeedLabel
        : widget.label;
    final mid = ProcessModeTokens.tabActiveColor(widget.processType);

    return Listener(
      onPointerDown: (_) {
        _gesture.pointerDown();
        _syncHoldProgress();
      },
      onPointerUp: (_) {
        _gesture.pointerUp();
        _syncHoldProgress();
      },
      onPointerCancel: (_) {
        _gesture.pointerUp();
        _syncHoldProgress();
      },
      child: SizedBox(
        width: ProcessModeDimens.quickSideButtonWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_holdProgress, _breath]),
              builder: (context, child) {
                // lws-ui GradientButton zoom: shrinkRatio 0.4→0 expands
                // center mid-color band to both edges while holding.
                // Latched: reverse breathe 0↔0.4.
                const maxShrink = 0.4;
                final double? shrinkRatio;
                if (retractHighlight && !isFeed) {
                  shrinkRatio = 0.0;
                } else if (latched) {
                  shrinkRatio = maxShrink * _breath.value;
                } else if (isFeed && _gesture.pressed) {
                  shrinkRatio =
                      maxShrink * (1.0 - _holdProgress.value.clamp(0.0, 1.0));
                } else {
                  shrinkRatio = null;
                }
                return SizedBox(
                  width: ProcessModeDimens.quickSideButtonWidth,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showProgress || retractHighlight)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FeedHoldProgressPainter(
                              mid: mid,
                              shrinkRatio: shrinkRatio ?? maxShrink,
                              active: shrinkRatio != null,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical:
                              ProcessModeDimens.quickSideOpVerticalPadding,
                        ),
                        child: child,
                      ),
                    ],
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    widget.enabled ? widget.iconAsset : widget.disabledIconAsset,
                    width: ProcessModeDimens.quickSideOpIconSize,
                    height: ProcessModeDimens.quickSideOpIconSize,
                    color: widget.enabled ? null : fg,
                    colorBlendMode: widget.enabled ? null : BlendMode.srcIn,
                    opacity: widget.enabled
                        ? null
                        : const AlwaysStoppedAnimation(0.5),
                  ),
                  const SizedBox(width: ProcessModeDimens.quickSideOpIconGap),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: ProcessModeDimens.quickSideOpLabelSize,
                        height: 1.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isFeed && widget.enabled && !latched)
              Transform.translate(
                offset: const Offset(0, 10),
                child: Text(
                  DeviceControlFeedbackCopy.feedHoldHint,
                  key: const ValueKey('device-control-feed-hold-hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ProcessModeTokens.tabInactiveText,
                    fontSize: 21,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Soft process-color band matching lws-ui `GradientButton` zoom type:
/// transparent → mid → transparent with stops at [shrink, 0.5, 1-shrink].
/// Hold: shrink 0.4→0 (center expands to both edges). Latch: breathe 0↔0.4.
final class _FeedHoldProgressPainter extends CustomPainter {
  _FeedHoldProgressPainter({
    required this.mid,
    required this.shrinkRatio,
    required this.active,
  });

  final Color mid;
  final double shrinkRatio;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active || size.width <= 0 || size.height <= 0) {
      return;
    }

    final shrink = shrinkRatio.clamp(0.0, 0.5);
    final leftPos = shrink;
    const centerPos = 0.5;
    final rightPos = 1.0 - shrink;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0x00000000),
          mid,
          const Color(0x00000000),
        ],
        stops: [leftPos, centerPos, rightPos],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _FeedHoldProgressPainter oldDelegate) {
    return oldDelegate.mid != mid ||
        oldDelegate.shrinkRatio != shrinkRatio ||
        oldDelegate.active != active;
  }
}
