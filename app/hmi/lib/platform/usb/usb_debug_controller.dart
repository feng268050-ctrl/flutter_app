/// Manual USB Debug preference: ON = OTG peripheral / plug-ssh; OFF = OTG host (keyboard).
abstract class UsbDebugController {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}
