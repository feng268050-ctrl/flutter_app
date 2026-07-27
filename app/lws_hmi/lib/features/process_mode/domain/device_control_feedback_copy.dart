/// EN feedback strings for Quick/Engineer device controls (lws-ui `values/strings.xml`).
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
}
