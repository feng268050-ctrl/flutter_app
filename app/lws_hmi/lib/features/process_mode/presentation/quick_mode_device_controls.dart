import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
            clipBehavior: Clip.none,
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

/// lws-ui parity: short press is a 500ms pulse; hold ≥500ms runs while
/// pressed; Feed held ~3s latches until tapped again. Retract never latches.
///
/// Feed paints a mode-color horizontal GradientButton band (transparent ends,
/// mid accent): hold-run = 2.5s one-shot center→edges over icon+label width;
/// latched = end-band breathe.
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

final class _ManualWireButtonState extends State<_ManualWireButton> {
  late final ManualWireGesture _gesture = ManualWireGesture(
    controller: widget.controller,
    retract: widget.retract,
    isEnabled: () => widget.enabled,
    isActive: () => widget.active,
    onMessage: widget.onMessage,
    onVisualChanged: () {
      if (mounted) {
        setState(() {});
        _syncBandBreath();
      }
    },
  );

  /// `holding` | `latched` | null — which gradient driver is active.
  String? _breathPhase;

  /// Hold-run one-shot expand (wall clock; flutter-pi may not tick
  /// [AnimationController] reliably during a static press).
  DateTime? _holdExpandStartedAt;

  /// Latch breathe phase origin.
  DateTime? _latchBreathStartedAt;

  /// Triangle-wave offset so latch can hand off from a fully expanded hold.
  double _latchBreathPhaseOffset = 0;

  Timer? _gradientTimer;

  /// Drives [CustomPaint] repaints on flutter-pi where [setState] alone may
  /// not schedule frames during a static press.
  final ValueNotifier<int> _gradientRepaint = ValueNotifier<int>(0);

  @override
  void dispose() {
    _gradientTimer?.cancel();
    _gradientRepaint.dispose();
    _gesture.dispose();
    super.dispose();
  }

  void _syncBandBreath() {
    if (widget.retract) {
      return;
    }
    // Match Android `startFeedClick || isContinuousFeed` — not raw press.
    final holding = _gesture.holdingRun;
    final latched = _gesture.latched;

    if (holding) {
      if (_breathPhase != 'holding') {
        _breathPhase = 'holding';
        _holdExpandStartedAt = DateTime.now();
        _latchBreathStartedAt = null;
        _latchBreathPhaseOffset = 0;
        _startGradientTimer();
        _gradientRepaint.value++;
      }
    } else if (latched) {
      if (_breathPhase != 'latched') {
        final wasHolding = _breathPhase == 'holding';
        _breathPhase = 'latched';
        _holdExpandStartedAt = null;
        _latchBreathStartedAt = DateTime.now();
        // Hold ends at breath=1 (shrink=0); start latch triangle there.
        _latchBreathPhaseOffset = wasHolding ? 0.5 : 0;
        _startGradientTimer();
        _gradientRepaint.value++;
      }
    } else if (_breathPhase != null) {
      _breathPhase = null;
      _holdExpandStartedAt = null;
      _latchBreathStartedAt = null;
      _latchBreathPhaseOffset = 0;
      _gradientTimer?.cancel();
      _gradientTimer = null;
    }
  }

  void _startGradientTimer() {
    _gradientTimer?.cancel();
    _gradientTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) {
        return;
      }
      if (_breathPhase == 'holding' &&
          _holdExpandStartedAt != null &&
          DateTime.now().difference(_holdExpandStartedAt!) >=
              FeedHoldGradient.holdExpandDuration) {
        _gradientTimer?.cancel();
        _gradientTimer = null;
      }
      // flutter-pi may not vsync during a static press; force a frame.
      SchedulerBinding.instance.scheduleFrame();
      _gradientRepaint.value++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFeed = !widget.retract;
    final latched = isFeed && _gesture.latched;
    final holdingRun = isFeed && _gesture.holdingRun;
    final showFeedGradient = isFeed &&
        (holdingRun || latched || _breathPhase != null);
    final retractHighlight =
        !isFeed && widget.enabled && (widget.active || _gesture.pressed);
    final fg =
        widget.enabled ? Colors.white : ProcessModeTokens.sideOperationDisabled;
    final label = latched
        ? DeviceControlFeedbackCopy.continuousFeedLabel
        : widget.label;
    final mid = ProcessModeTokens.feedHoldGradientMid(widget.processType);

    return Listener(
      onPointerDown: (_) {
        _gesture.pointerDown();
        _syncBandBreath();
      },
      onPointerUp: (_) {
        _gesture.pointerUp();
        _syncBandBreath();
      },
      onPointerCancel: (_) {
        _gesture.pointerUp();
        _syncBandBreath();
      },
      child: SizedBox(
        width: ProcessModeDimens.quickSideButtonWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) {
                final showGradientBand = (retractHighlight && !isFeed) ||
                    showFeedGradient;
                return SizedBox(
                  width: ProcessModeDimens.quickSideButtonWidth,
                  child: Center(
                    child: IntrinsicWidth(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        alignment: Alignment.center,
                        children: [
                          if (showGradientBand)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FeedHoldGradientPainter(
                                  repaint: _gradientRepaint,
                                  mid: mid,
                                  retractHighlight: retractHighlight && !isFeed,
                                  phase: _breathPhase,
                                  holdingRun: holdingRun,
                                  latched: latched,
                                  holdExpandStartedAt: _holdExpandStartedAt,
                                  latchBreathStartedAt: _latchBreathStartedAt,
                                  latchBreathPhaseOffset:
                                      _latchBreathPhaseOffset,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: ProcessModeDimens
                                  .quickSideOpVerticalPadding,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  widget.enabled
                                      ? widget.iconAsset
                                      : widget.disabledIconAsset,
                                  width: ProcessModeDimens.quickSideOpIconSize,
                                  height:
                                      ProcessModeDimens.quickSideOpIconSize,
                                  color: widget.enabled ? null : fg,
                                  colorBlendMode:
                                      widget.enabled ? null : BlendMode.srcIn,
                                  opacity: widget.enabled
                                      ? null
                                      : const AlwaysStoppedAnimation(0.5),
                                ),
                                const SizedBox(
                                  width: ProcessModeDimens.quickSideOpIconGap,
                                ),
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fg,
                                    fontSize:
                                        ProcessModeDimens.quickSideOpLabelSize,
                                    height: 1.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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

/// Feed hold / continuous-feed gradient math (lws-ui `GradientButton` zoom).
///
/// Mid band width is absolute px on the icon+label paint box:
/// first paint [initialMidWidth] (18), then expands to full paint width.
/// Stops `[shrink, 0.5, 1-shrink]` with transparent → mid → transparent.
abstract final class FeedHoldGradient {
  /// First-appear mid-band width (hold-run / latch min).
  static const double initialMidWidth = 18;

  /// Hold-run window: 3s latch minus 500ms hold-to-run.
  static final Duration holdExpandDuration =
      DeviceControlTiming.wireFeedLatchDelay -
      DeviceControlTiming.wireHoldToRun;

  /// Android `animation_duration` while `isContinuousFeed`.
  static const Duration latchBreathDuration = Duration(milliseconds: 3000);

  /// Hold one-shot: breath 0→1 ⇒ mid 18px → full width.
  /// Latch breathe: breath 0↔1 ⇒ mid 18px ↔ full width.
  static double breathValue({
    required String? phase,
    required DateTime? holdExpandStartedAt,
    required DateTime? latchBreathStartedAt,
    required double latchBreathPhaseOffset,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (phase == 'holding') {
      final start = holdExpandStartedAt;
      if (start == null) {
        return 0;
      }
      final total = holdExpandDuration.inMilliseconds;
      if (total <= 0) {
        return 1;
      }
      final ms = clock.difference(start).inMilliseconds;
      return (ms / total).clamp(0.0, 1.0);
    }
    if (phase == 'latched') {
      final start = latchBreathStartedAt;
      if (start == null) {
        return 0;
      }
      final period = latchBreathDuration.inMilliseconds;
      if (period <= 0) {
        return 0;
      }
      final phaseT =
          ((clock.difference(start).inMilliseconds / period) +
                  latchBreathPhaseOffset) %
              1.0;
      return phaseT <= 0.5 ? phaseT * 2 : (1 - phaseT) * 2;
    }
    return 0;
  }

  /// Visible mid-band width for [paintWidth] at [breathValue] (0=narrow, 1=full).
  static double midWidth({
    required double paintWidth,
    required double breathValue,
  }) {
    if (paintWidth <= 0) {
      return 0;
    }
    final t = breathValue.clamp(0.0, 1.0);
    final minW = initialMidWidth.clamp(0.0, paintWidth);
    return minW + (paintWidth - minW) * t;
  }

  /// Shrink from absolute mid width: `(1 - mid/paintWidth) / 2`.
  static double shrinkRatio({
    required double paintWidth,
    required double midWidth,
  }) {
    if (paintWidth <= 0) {
      return 0.5;
    }
    final mid = midWidth.clamp(0.0, paintWidth);
    return ((1.0 - mid / paintWidth) / 2.0).clamp(0.0, 0.5);
  }

  static LinearGradient gradient({
    required Color mid,
    required double shrinkRatio,
  }) {
    final shrink = shrinkRatio.clamp(0.0, 0.5);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0x00000000),
        mid,
        const Color(0x00000000),
      ],
      stops: [shrink, 0.5, 1.0 - shrink],
    );
  }
}

/// Canvas draw of [FeedHoldGradient] (lws-ui `GradientButton#onDraw`).
final class _FeedHoldGradientPainter extends CustomPainter {
  _FeedHoldGradientPainter({
    required Listenable repaint,
    required this.mid,
    required this.retractHighlight,
    required this.phase,
    required this.holdingRun,
    required this.latched,
    required this.holdExpandStartedAt,
    required this.latchBreathStartedAt,
    required this.latchBreathPhaseOffset,
  }) : super(repaint: repaint);

  final Color mid;
  final bool retractHighlight;
  final String? phase;
  final bool holdingRun;
  final bool latched;
  final DateTime? holdExpandStartedAt;
  final DateTime? latchBreathStartedAt;
  final double latchBreathPhaseOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final double shrink;
    if (retractHighlight) {
      shrink = 0.0;
    } else {
      final breath = FeedHoldGradient.breathValue(
        phase: phase,
        holdExpandStartedAt: holdExpandStartedAt,
        latchBreathStartedAt: latchBreathStartedAt,
        latchBreathPhaseOffset: latchBreathPhaseOffset,
      );
      final bandW = FeedHoldGradient.midWidth(
        paintWidth: size.width,
        breathValue: breath,
      );
      shrink = FeedHoldGradient.shrinkRatio(
        paintWidth: size.width,
        midWidth: bandW,
      );
    }
    final paint = Paint()
      ..shader = FeedHoldGradient.gradient(
        mid: mid,
        shrinkRatio: shrink,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _FeedHoldGradientPainter oldDelegate) {
    return oldDelegate.mid != mid ||
        oldDelegate.retractHighlight != retractHighlight ||
        oldDelegate.phase != phase ||
        oldDelegate.holdingRun != holdingRun ||
        oldDelegate.latched != latched ||
        oldDelegate.holdExpandStartedAt != holdExpandStartedAt ||
        oldDelegate.latchBreathStartedAt != latchBreathStartedAt ||
        oldDelegate.latchBreathPhaseOffset != latchBreathPhaseOffset;
  }
}
