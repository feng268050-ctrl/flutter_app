/// On-demand LAN/WLAN SSH debug (peer of proxy under `hal/network`).
///
/// Concrete Linux type: [LinuxSshDebugController] (exported from `hal/network.dart`).
library;

/// Portable SSH debug enable/disable.
abstract class SshDebug {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

/// Migration alias — prefer [SshDebug].
typedef SshDebugController = SshDebug;
