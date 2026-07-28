/// Flutter asset paths for this HMI product's HAL configs.
///
/// Product-owned (not `cyber_hal`): the same motherboard may ship different
/// GPIO / Modbus maps in other apps. Keep catalogs under [assets/hal/].
abstract final class HmiHalAssets {
  static const boardProfile = 'assets/hal/board_profile.json';
  static const gpio = 'assets/hal/gpio.json';
  static const gpioSim = 'assets/hal/gpio.sim.json';
  static const modbus = 'assets/hal/modbus.json';

  /// GPIO catalog for the active board (sim guest uses file-backed gpio-sim).
  static String gpioForBoard(String boardId) =>
      boardId == 'sim' ? gpioSim : gpio;
}
