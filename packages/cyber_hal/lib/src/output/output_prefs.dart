/// Default preference files for [hal/output] (mouse.conf-style key=value).
///
/// - [displayConf]: `backlight`, `auto_sleep`, `orientation`
/// - [soundConf]: `volume`, `button_feedback`
/// - [powerConf]: `mode` (`performance` / `balanced`)
abstract final class OutputPrefs {
  static const displayConf = '/var/lib/hal/display.conf';
  static const soundConf = '/var/lib/hal/sound.conf';
  static const powerConf = '/var/lib/hal/power.conf';

  static const keyBacklight = 'backlight';
  static const keyAutoSleep = 'auto_sleep';
  static const keyOrientation = 'orientation';
  static const keyVolume = 'volume';
  static const keyButtonFeedback = 'button_feedback';
  static const keyPowerMode = 'mode';
}
