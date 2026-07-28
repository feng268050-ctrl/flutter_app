/// EN feedback strings for Quick/Engineer device controls (lws-ui `values/strings.xml`).
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';

abstract final class DeviceControlFeedbackCopy {
  static const manualGasOn = 'Manual gas on';
  static const manualGasOff = 'Manual gas turned off';
  static const autoWireFeedOn = 'Auto wire feed enabled';
  static const autoWireFeedOff = 'Wire feed turned off';

  /// Continuous feed latch entered (`feed_ongoing_text`).
  static const feedOngoing = 'Feeding…';

  /// Latched continuous feed stopped by tap (`end_feed`).
  static const stopFeed = 'Stop Feed+';

  /// Feed short-press / hold-release success (`feed_successful`).
  static const feedPulseSuccess = 'Feed+ started';

  /// Retract short-press success (`feed_success_text`).
  static const retractPulseSuccess = 'Feed started';

  /// Retract hold release (`feed_end_text`).
  static const feedStopped = 'Feed stopped';

  static const operationFailed = 'Operation failed';

  /// Idle Feed primary label (`btn_feed_text`).
  static const feedLabel = 'Feed';

  /// Latched continuous feed label (`continuous_feeding_text`).
  static const continuousFeedLabel = 'Continuous Feed';

  /// Sub-hint under Feed (`feed_sub_hold_hint`).
  static const feedHoldHint = 'Hold 3s to keep on';

  /// Record Work cannot start (`unable_to_open_the_camera_title`).
  static const cameraUnavailable = 'Camera unavailable';

  /// Side ops / More Parameters blocked while laser is open.
  static const endOfWorkFirst = 'End of work first';

  /// Feed / Retract / Auto Wire outside continuous welding.
  static const wireUnavailableInMode = 'Wire feed unavailable in this mode';

  /// Frost Operation failed title (`operation_failed_text`).
  static const operationFailedTitle = 'Operation failed';

  /// Key switch off while Laser Enable (`check_key_error_text`).
  static const keySwitchOffError = 'Key switch is off';

  /// E-stop active (`check_e_stop_state_error`).
  static const emergencyStopError = 'Device is in E-stop';

  /// Tip body for Laser Enable preflight when key / e-stop is not reset.
  static String tipForLaserEnableBlock(LaserEnableBlockReason reason) {
    return switch (reason) {
      LaserEnableBlockReason.keySwitchOff => keySwitchOffError,
      LaserEnableBlockReason.emergencyStop => emergencyStopError,
      _ => reason.message,
    };
  }

  /// Whether [reason] should use Operation-failed tip (not Toast).
  static bool isSafetyTipBlock(LaserEnableBlockReason reason) =>
      reason == LaserEnableBlockReason.keySwitchOff ||
      reason == LaserEnableBlockReason.emergencyStop;
}
