import 'dart:io';

/// Best-effort USB / HID mouse presence for Demo status.
///
/// Listing `/dev/input/by-id` must use `followLinks: false` (see keyboard probe).
class UsbHidMouseProbe {
  const UsbHidMouseProbe();

  /// Returns a short human status.
  Future<String> statusLine() async {
    try {
      final byId = Directory('/dev/input/by-id');
      if (await byId.exists()) {
        final mice = <String>[];
        await for (final entity in byId.list(followLinks: false)) {
          final name = entity.path.split('/').last;
          final lower = name.toLowerCase();
          if (lower.contains('mouse') || lower.contains('event-mouse')) {
            mice.add(name);
          }
        }
        mice.sort();
        if (mice.isNotEmpty) {
          return 'detected: ${mice.join(', ')}';
        }
      }

      final byPath = Directory('/dev/input/by-path');
      if (await byPath.exists()) {
        final usbMice = <String>[];
        await for (final entity in byPath.list(followLinks: false)) {
          final name = entity.path.split('/').last;
          final lower = name.toLowerCase();
          if (lower.contains('usb') &&
              (lower.contains('mouse') || lower.contains('event-mouse'))) {
            usbMice.add(name);
          }
        }
        usbMice.sort();
        if (usbMice.isNotEmpty) {
          return 'detected: ${usbMice.join(', ')}';
        }
      }

      return 'not detected';
    } catch (_) {
      return 'probe unavailable';
    }
  }
}
