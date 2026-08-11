/// Default preference files for [hal/output] (mouse.conf-style key=value).
///
/// - [displayConf]: `backlight`, `auto_sleep`, `orientation`, `wallpaper`
/// - [soundConf]: `volume`, `button_feedback`
/// - [powerConf]: `mode` (`performance` / `balanced`)
abstract final class OutputPrefs {
  static const displayConf = '/var/lib/hal/display.conf';
  static const soundConf = '/var/lib/hal/sound.conf';
  static const powerConf = '/var/lib/hal/power.conf';

  /// Packaged wallpaper presets (read-only rootfs).
  static const wallpaperPresetsDir = '/usr/share/hal/wallpapers';

  /// Active installed wallpaper (copied from a preset on select).
  static const wallpaperActivePath = '/var/lib/hal/wallpaper.png';

  static const keyBacklight = 'backlight';
  static const keyAutoSleep = 'auto_sleep';
  static const keyOrientation = 'orientation';
  static const keyWallpaper = 'wallpaper';
  static const keyWallpaperId = 'wallpaper_id';
  static const keyUiScale = 'ui_scale';
  static const keyVolume = 'volume';
  static const keyButtonFeedback = 'button_feedback';
  static const keyPowerMode = 'mode';
}
