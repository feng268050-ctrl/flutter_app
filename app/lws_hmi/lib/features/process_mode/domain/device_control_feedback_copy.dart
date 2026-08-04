import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Localized feedback strings for Quick/Engineer device controls.
abstract final class DeviceControlFeedbackCopy {
  static String manualGasOn(AppLocalizations l10n) =>
      l10n.deviceControlManualGasOn;
  static String manualGasOff(AppLocalizations l10n) =>
      l10n.deviceControlManualGasOff;
  static String autoWireFeedOn(AppLocalizations l10n) =>
      l10n.deviceControlAutoWireFeedOn;
  static String autoWireFeedOff(AppLocalizations l10n) =>
      l10n.deviceControlAutoWireFeedOff;

  /// Continuous feed latch entered (`feed_ongoing_text`).
  static String feedOngoing(AppLocalizations l10n) =>
      l10n.deviceControlFeedOngoing;

  /// Latched continuous feed stopped by tap (`end_feed`).
  static String stopFeed(AppLocalizations l10n) => l10n.deviceControlStopFeed;

  /// Feed short-press / hold-release success (`feed_successful`).
  static String feedPulseSuccess(AppLocalizations l10n) =>
      l10n.deviceControlFeedPulseSuccess;

  /// Retract short-press success (`feed_success_text`).
  static String retractPulseSuccess(AppLocalizations l10n) =>
      l10n.deviceControlRetractPulseSuccess;

  /// Retract hold release (`feed_end_text`).
  static String feedStopped(AppLocalizations l10n) =>
      l10n.deviceControlFeedStopped;

  static String operationFailed(AppLocalizations l10n) =>
      l10n.deviceControlOperationFailed;

  /// Idle Feed primary label (`btn_feed_text`).
  static String feedLabel(AppLocalizations l10n) => l10n.feed;

  /// Latched continuous feed label (`continuous_feeding_text`).
  static String continuousFeedLabel(AppLocalizations l10n) =>
      l10n.deviceControlContinuousFeedLabel;

  /// Sub-hint under Feed (`feed_sub_hold_hint`).
  static String feedHoldHint(AppLocalizations l10n) =>
      l10n.deviceControlFeedHoldHint;

  /// Record Work cannot start (`unable_to_open_the_camera_title`).
  static String cameraUnavailable(AppLocalizations l10n) =>
      l10n.deviceControlCameraUnavailable;

  /// Side ops / More Parameters blocked while laser is open.
  static String endOfWorkFirst(AppLocalizations l10n) =>
      l10n.deviceControlEndOfWorkFirst;

  /// End of work Modbus write / reconcile failed (bus or C001).
  static String endOfWorkFailed(AppLocalizations l10n) =>
      l10n.deviceControlEndOfWorkFailed;

  /// Feed / Retract / Auto Wire outside continuous welding.
  static String wireUnavailableInMode(AppLocalizations l10n) =>
      l10n.deviceControlWireUnavailableInMode;

  /// Frost Operation failed title (`operation_failed_text`).
  static String operationFailedTitle(AppLocalizations l10n) =>
      l10n.deviceControlOperationFailed;

  /// Key switch off while Laser Enable (`check_key_error_text`).
  static String keySwitchOffError(AppLocalizations l10n) =>
      l10n.deviceControlKeySwitchOffError;

  /// E-stop active (`check_e_stop_state_error`).
  static String emergencyStopError(AppLocalizations l10n) =>
      l10n.deviceControlEmergencyStopError;

  /// User-facing copy when [disableLaser] returns a block reason.
  static String messageForDisable(
    AppLocalizations l10n,
    LaserEnableBlockReason reason,
  ) {
    return switch (reason) {
      LaserEnableBlockReason.writeFailed => endOfWorkFailed(l10n),
      _ => reason.localizedMessage(l10n),
    };
  }

  /// Tip body for Laser Enable preflight when key / e-stop is not reset.
  static String tipForLaserEnableBlock(
    AppLocalizations l10n,
    LaserEnableBlockReason reason,
  ) {
    return switch (reason) {
      LaserEnableBlockReason.keySwitchOff => keySwitchOffError(l10n),
      LaserEnableBlockReason.emergencyStop => emergencyStopError(l10n),
      _ => reason.localizedMessage(l10n),
    };
  }

  /// Whether [reason] should use Operation-failed tip (not Toast).
  static bool isSafetyTipBlock(LaserEnableBlockReason reason) =>
      reason == LaserEnableBlockReason.keySwitchOff ||
      reason == LaserEnableBlockReason.emergencyStop;
}
