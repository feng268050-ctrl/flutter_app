/// On-demand LAN/WLAN SSH debug.
///
/// Concrete Linux type: [LinuxSshDebugController] (exported from `hal/debug.dart`).
library;

/// Portable SSH debug enable/disable.
abstract class SshDebug {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

/// Migration alias — prefer [SshDebug].
typedef SshDebugController = SshDebug;
