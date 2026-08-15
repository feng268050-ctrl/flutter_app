/// Flutter asset paths for this HMI product's HAL configs.
///
/// Product-owned (not `cyber_hal`): the same motherboard may ship different
/// GPIO / Modbus maps in other apps. Keep catalogs under [assets/hal/].
abstract final class HmiHalAssets {
  static const boardProfile = 'assets/hal/board_profile.json';
  static const gpioYnh960 = 'assets/hal/gpio.ynh960.json';
  static const gpioSim = 'assets/hal/gpio.sim.json';
  static const gpioEk3562 = 'assets/hal/gpio.ek3562.json';
  static const modbus = 'assets/hal/modbus.json';

  /// GPIO catalog for the active board (sim guest uses file-backed gpio-sim).
  static String gpioForBoard(String boardId) {
    switch (boardId) {
      case 'sim':
        return gpioSim;
      case 'ek3562':
        return gpioEk3562;
      case 'ynh960':
      case 'ynh961':
      case 'ynh962':
      default:
        return gpioYnh960;
    }
  }
}
