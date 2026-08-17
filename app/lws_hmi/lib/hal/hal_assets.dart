import 'package:cyber_hal/cyber_hal.dart';

/// Flutter asset paths for this HMI product's HAL configs.
///
/// Product-owned (not `cyber_hal`): the same motherboard may ship different
/// GPIO / Modbus maps in other apps. Keep catalogs under [assets/hal/].
/// Board profile itself is OEM (`/run/hmi/board_profile.json` on device) —
/// this App does **not** ship a `board_profile.json` Flutter asset.
/// Modbus RTU nodes live in `modbus.json` → `transport.device_by_board`.
abstract final class HmiHalAssets {
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

  /// Host/desktop only — not a Flutter asset; mirrors a minimal OEM shape so
  /// UI work can run without `/run/hmi/board_profile.json`.
  static BoardProfile hostDevBoardProfile() {
    return BoardProfile.fromJsonString('''
{
  "board_id": "ynh960",
  "display_name": "Host / desktop stub",
  "model_hint": "host",
  "secrets_backend": "software",
  "capabilities": [
    "ethernet",
    "wifi",
    "proxy",
    "bluetooth",
    "backlight",
    "volume",
    "keyboard",
    "mouse",
    "gpio",
    "modbus",
    "sysInfo",
    "datetime",
    "sshDebug"
  ],
  "net_roles": {
    "ethernet.primary": "eth0",
    "wifi.station": "wlan0"
  },
  "storage_mounts": ["/", "/userdata"],
  "route_metrics": {
    "wlan0": 100,
    "eth0": 2000
  },
  "helpers": {}
}
''').withProductConfigs(
      gpio: gpioForBoard('ynh960'),
      modbus: modbus,
    );
  }
}
