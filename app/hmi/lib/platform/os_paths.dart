/// FHS subsystem paths on the appliance OS (see os-path-layout spec).
abstract final class OsPaths {
  static const varWpa = '/var/lib/wpa_supplicant';
  static const varNetwork = '/var/lib/network';
  static const varBluetooth = '/var/lib/bluetooth';
  /// HAL / system platform prefs (`display.conf`, `mouse.conf`, `product.ini`, …).
  static const varHal = '/var/lib/hal';
  /// HMI App-owned stores (misc/advanced JSON, alarm DB, push/debug staging).
  static const varHmi = '/var/lib/hmi';
  /// Runtime stamps (tmpfs); App markers under `/run/hmi`, display-stack at `/run/display-stack`.
  static const runHmi = '/run/hmi';
  static const runDisplayStack = '/run/display-stack';
  static const etcDisplayStack = '/etc/display-stack';
  static const libexecWpa = '/usr/libexec/wpa';
  static const libexecNetwork = '/usr/libexec/network';
  static const libexecBluetooth = '/usr/libexec/bluetooth';
  static const libexecHmi = '/usr/libexec/hmi';
}
