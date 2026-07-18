import 'dart:io';

/// Best-effort USB / HID keyboard presence for P2.1 Demo status.
///
/// Does not decode keys — Flutter Focus/`TextField` receives HID via
/// libinput/flutter-pi once a keyboard is enumerated.
class UsbHidKeyboardProbe {
  const UsbHidKeyboardProbe();

  /// Returns a short human status, or null if probing is unsupported / failed.
  Future<String> statusLine() async {
    try {
      final byId = Directory('/dev/input/by-id');
      if (await byId.exists()) {
        final entries = await byId.list().toList();
        final kbds = entries
            .whereType<Link>()
            .map((e) => e.path.split('/').last)
            .where((n) => n.toLowerCase().contains('kbd'))
            .toList()
          ..sort();
        if (kbds.isNotEmpty) {
          return 'detected: ${kbds.join(', ')}';
        }
      }

      final byPath = Directory('/dev/input/by-path');
      if (await byPath.exists()) {
        final entries = await byPath.list().toList();
        final usbKbds = entries
            .whereType<Link>()
            .map((e) => e.path.split('/').last)
            .where(
              (n) =>
                  n.toLowerCase().contains('usb') &&
                  n.toLowerCase().contains('kbd'),
            )
            .toList()
          ..sort();
        if (usbKbds.isNotEmpty) {
          return 'detected: ${usbKbds.join(', ')}';
        }
      }

      return 'not detected';
    } catch (_) {
      return 'probe unavailable';
    }
  }
}
