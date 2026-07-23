/// Default preference files for [hal/output] (mouse.conf-style key=value).
///
/// - [displayConf]: `backlight`, `auto_sleep`
/// - [soundConf]: `volume`, `button_feedback`
abstract final class OutputPrefs {
  static const displayConf = '/var/lib/hmi/display.conf';
  static const soundConf = '/var/lib/hmi/sound.conf';

  static const keyBacklight = 'backlight';
  static const keyAutoSleep = 'auto_sleep';
  static const keyVolume = 'volume';
  static const keyButtonFeedback = 'button_feedback';
}
