import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_region_frost.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_outline_button.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_button.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

/// Quick-mode bottom composition: left/right side ops + center trapezoid.
///
/// Side ops reuse Engineer Retract/Feed outline chrome
/// ([ProcessModeOutlineButton] / [ProcessModeOutlineWireButton]).
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

  static const _sideButtonGap = 20.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        // lws-ui `isOpenLaser()` — session bit only, not emission feedback.
        final laserOpen = controller.laserSessionArmed;
        // lws-ui BlurUtils: side groups get σ=15 snapshot + lock (Quick only).
        final scale =
            ProcessModeDimens.dashboardScaleFor(MediaQuery.sizeOf(context));
        return SizedBox.expand(
          key: const ValueKey('device-control-bar'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
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
                      // Separates mode / material wheels from side ops.
                      _QuickZoneDivider(
                        key: const ValueKey('quick-mode-zone-divider-left'),
                        processType: processType,
                      ),
                      const SizedBox(
                        height: ProcessModeDimens.quickSideOpGapBelowDivider,
                      ),
                      // Hint-height spacer inside frost so Manual Gas lines up
                      // with Feed after the right column includes the hold hint.
                      LaserEnableRegionFrost(
                        armed: laserOpen,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_wireCapable)
                              const SizedBox(
                                height: ProcessModeDimens.feedHoldHintSlotHeight,
                              ),
                            ProcessModeOutlineButton(
                              key: const ValueKey('device-control-manual-gas'),
                              label: l10n.manualGas,
                              leading: _materialIcon(Icons.air),
                              selected: controller.manualGas,
                              enabled: true,
                              onPressed: () =>
                                  unawaited(_toggleManualGas(context, l10n)),
                            ),
                            const SizedBox(height: _sideButtonGap),
                            ProcessModeOutlineButton(
                              key: const ValueKey(
                                  'device-control-auto-wire-feed'),
                              label: l10n.autoWireFeed,
                              leading: _materialIcon(Icons.sync),
                              selected:
                                  controller.autoWireFeed && _wireCapable,
                              enabled: _wireCapable,
                              iconLabelClearance:
                                  ProcessModeOutlineChrome.noIconLabelClearance,
                              onPressed: () =>
                                  unawaited(_toggleAutoWire(context, l10n)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                      _QuickZoneDivider(
                        key: const ValueKey('quick-mode-zone-divider-right'),
                        processType: processType,
                      ),
                      const SizedBox(
                        height: ProcessModeDimens.quickSideOpGapBelowDivider,
                      ),
                      // Include hold hint in frost (lws-ui rightBottomBtnGroup).
                      LaserEnableRegionFrost(
                        armed: laserOpen,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_wireCapable) _FeedHoldHintSlot(l10n: l10n),
                            ProcessModeOutlineWireButton(
                              key: const ValueKey('device-control-feed'),
                              label: DeviceControlFeedbackCopy.feedLabel(l10n),
                              latchedLabel:
                                  DeviceControlFeedbackCopy.continuousFeedLabel(
                                l10n,
                              ),
                              leading: _wireIcon(retract: false),
                              enabled: _wireCapable,
                              laserBlocked: laserOpen,
                              retract: false,
                              active: controller.wireWork &&
                                  !controller.wireRetracting,
                              controller: controller,
                              onMessage: (message) =>
                                  _toast(context, message),
                            ),
                            const SizedBox(height: _sideButtonGap),
                            ProcessModeOutlineWireButton(
                              key: const ValueKey('device-control-retract'),
                              label: l10n.retract,
                              leading: _wireIcon(retract: true),
                              enabled: _wireCapable,
                              laserBlocked: laserOpen,
                              retract: true,
                              active: controller.wireWork &&
                                  controller.wireRetracting,
                              controller: controller,
                              onMessage: (message) =>
                                  _toast(context, message),
                            ),
                          ],
                        ),
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
                  onBlocked: (message) {
                    if (message ==
                            LaserEnableBlockReason.alarmBlocked
                                .localizedMessage(l10n) ||
                        message ==
                            LaserEnableBlockReason.keySwitchOff
                                .localizedMessage(l10n) ||
                        message ==
                            LaserEnableBlockReason.emergencyStop
                                .localizedMessage(l10n) ||
                        message ==
                            DeviceControlFeedbackCopy.keySwitchOffError(
                              l10n,
                            ) ||
                        message ==
                            DeviceControlFeedbackCopy.emergencyStopError(
                              l10n,
                            )) {
                      return;
                    }
                    _toast(context, message);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _laserOpen => controller.laserSessionArmed;

  /// White glyph; [_OutlineFace] tints via [ColorFiltered] like the old WebPs.
  static Widget _materialIcon(IconData icon) {
    return Icon(
      icon,
      size: ProcessModeOutlineChrome.iconSize,
      color: Colors.white,
    );
  }

  /// Feed/Retract share the retract glyph; retract is mirrored horizontally.
  static Widget _wireIcon({required bool retract}) {
    final icon = _materialIcon(Icons.output);
    if (!retract) {
      return icon;
    }
    return Transform.flip(flipX: true, child: icon);
  }

  Future<void> _toggleManualGas(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (controller.busy) {
      _toast(context, LaserEnableBlockReason.busy.localizedMessage(l10n));
      return;
    }
    if (_laserOpen) {
      _toast(context, DeviceControlFeedbackCopy.endOfWorkFirst(l10n));
      return;
    }
    final enabling = !controller.manualGas;
    final error = await controller.setManualGas(enabling);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _toast(
        context,
        controller.lastError ?? error.localizedMessage(l10n),
      );
      return;
    }
    _toast(
      context,
      enabling
          ? DeviceControlFeedbackCopy.manualGasOn(l10n)
          : DeviceControlFeedbackCopy.manualGasOff(l10n),
    );
  }

  Future<void> _toggleAutoWire(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (!_wireCapable) {
      return;
    }
    if (controller.busy) {
      _toast(context, LaserEnableBlockReason.busy.localizedMessage(l10n));
      return;
    }
    if (_laserOpen) {
      _toast(context, DeviceControlFeedbackCopy.endOfWorkFirst(l10n));
      return;
    }
    final enabling = !controller.autoWireFeed;
    final error = await controller.setAutoWireFeed(enabling);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _toast(
        context,
        controller.lastError ?? error.localizedMessage(l10n),
      );
      return;
    }
    _toast(
      context,
      enabling
          ? DeviceControlFeedbackCopy.autoWireFeedOn(l10n)
          : DeviceControlFeedbackCopy.autoWireFeedOff(l10n),
    );
  }

  void _toast(BuildContext context, String message) {
    ProcessModeToast.show(context, message);
  }
}

/// Three-stop gradient (transparent → mode accent → transparent) between the
/// mode/material wheels and the side operation buttons.
final class _QuickZoneDivider extends StatelessWidget {
  const _QuickZoneDivider({super.key, required this.processType});

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

/// Feed hold hint above Feed/Retract (inside laser frost with those buttons).
final class _FeedHoldHintSlot extends StatelessWidget {
  const _FeedHoldHintSlot({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProcessModeDimens.feedHoldHintSlotHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.topCenter,
        child: Text(
          DeviceControlFeedbackCopy.feedHoldHint(l10n),
          key: const ValueKey('device-control-feed-hold-hint'),
          textAlign: TextAlign.center,
          style: context.hmiTypography.settingsRowTitle.copyWith(
            color: ProcessModeOutlineChrome.actionOrange,
            height: 1.0,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
