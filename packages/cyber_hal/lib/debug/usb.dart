/// Micro-USB OTG / plug-ssh vs host.
///
/// Concrete Linux type: [LinuxUsbDebugController] (exported from `hal/debug.dart`).
///
/// ON = OTG peripheral / plug-ssh; OFF = OTG host (keyboard).
library;

/// Portable USB debug enable/disable (bool, not mode enum).
abstract class UsbDebug {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

/// Migration alias — prefer [UsbDebug].
typedef UsbDebugController = UsbDebug;
