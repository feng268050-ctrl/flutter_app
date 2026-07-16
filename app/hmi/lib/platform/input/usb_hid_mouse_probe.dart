import 'dart:io';

/// Best-effort USB / HID mouse presence for P2.1 Demo status.
class UsbHidMouseProbe {
  const UsbHidMouseProbe();

  /// Returns a short human status, or a probe-unavailable message.
  Future<String> statusLine() async {
    try {
      final byId = Directory('/dev/input/by-id');
      if (await byId.exists()) {
        final entries = await byId.list().toList();
        final mice = entries
            .whereType<Link>()
            .map((e) => e.path.split('/').last)
            .where((n) {
              final lower = n.toLowerCase();
              return lower.contains('mouse') || lower.contains('event-mouse');
            })
            .toList()
          ..sort();
        if (mice.isNotEmpty) {
          return 'detected: ${mice.join(', ')}';
        }
      }

      final byPath = Directory('/dev/input/by-path');
      if (await byPath.exists()) {
        final entries = await byPath.list().toList();
        final usbMice = entries
            .whereType<Link>()
            .map((e) => e.path.split('/').last)
            .where((n) {
              final lower = n.toLowerCase();
              return lower.contains('usb') && lower.contains('mouse');
            })
            .toList()
          ..sort();
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
