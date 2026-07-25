import 'dart:io';

/// Best-effort USB / HID keyboard presence for Demo status and [Keyboard.isPresent].
///
/// Does not decode keys — Flutter Focus/`TextField` receives HID via
/// libinput once a keyboard is enumerated.
///
/// **Important:** `/dev/input/by-id` entries are symlinks. Listing must use
/// `followLinks: false` — the default follows them into `event*` nodes and
/// they are no longer [Link]s, so a `whereType<Link>()` filter always misses.
///
/// **Builtin keys:** ynh960 (and similar) always expose `gpio-keys` /
/// power-button / `bt-powerkey` nodes with the Linux `kbd` handler. Those MUST
/// NOT count as a typing keyboard or CyberIME soft overlay is permanently
/// suppressed.
class UsbHidKeyboardProbe {
  const UsbHidKeyboardProbe();

  /// True when a keyboard-like input node is linked under `/dev/input`
  /// or advertised in `/proc/bus/input/devices` (excluding board buttons).
  Future<bool> isPresent() async {
    final line = await statusLine();
    return line != null && line.startsWith('detected:');
  }

  static bool looksLikeKeyboardName(String name) {
    final n = name.toLowerCase();
    return n.contains('kbd') || n.contains('keyboard');
  }

  /// Board power / front-panel keys that Linux still tags with the `kbd`
  /// handler — not a USB/BT typing keyboard for soft-IME suppression.
  static bool isBuiltinButtonDevice(String name) {
    final n = name.toLowerCase().trim();
    if (n.isEmpty) {
      return false;
    }
    if (n.contains('gpio-keys') ||
        n.contains('adc-keys') ||
        n.contains('pwrkey') ||
        n.contains('pwr-key') ||
        n.contains('powerkey') ||
        n.contains('power key') ||
        n.contains('power-key') ||
        n.contains('power button') ||
        n.contains('power-button')) {
      return true;
    }
    // Rockchip PMICs (rk809 / rk817 / …) expose a pwrkey input name.
    if (RegExp(r'rk\d+.*pwr').hasMatch(n)) {
      return true;
    }
    return false;
  }

  /// Symlink basenames under [dirPath] that look like keyboards.
  ///
  /// Public for unit tests (must list with `followLinks: false`).
  static Future<List<String>> keyboardLinksIn(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      return const [];
    }
    final found = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      final name = entity.path.split('/').last;
      if (looksLikeKeyboardName(name) && !isBuiltinButtonDevice(name)) {
        found.add(name);
      }
    }
    found.sort();
    return found;
  }

  /// `/proc/bus/input/devices` blocks whose Handlers include `kbd`, excluding
  /// board builtin button devices (see [isBuiltinButtonDevice]).
  static Future<List<String>> procKbdNames({
    String path = '/proc/bus/input/devices',
  }) async {
    try {
      final raw = await File(path).readAsString();
      final names = <String>[];
      String? name;
      for (final line in raw.split('\n')) {
        if (line.startsWith('N: Name=')) {
          name = line.substring('N: Name='.length).replaceAll('"', '');
        } else if (line.startsWith('H: Handlers=')) {
          final handlers = line.substring('H: Handlers='.length);
          if (handlers.split(RegExp(r'\s+')).contains('kbd') &&
              name != null &&
              !isBuiltinButtonDevice(name)) {
            names.add(name);
          }
          name = null;
        } else if (line.isEmpty) {
          name = null;
        }
      }
      return names;
    } catch (_) {
      return const [];
    }
  }

  /// Returns a short human status, or null if probing is unsupported / failed.
  Future<String?> statusLine() async {
    try {
      final byId = await keyboardLinksIn('/dev/input/by-id');
      if (byId.isNotEmpty) {
        return 'detected: ${byId.join(', ')}';
      }

      final byPath = await keyboardLinksIn('/dev/input/by-path');
      if (byPath.isNotEmpty) {
        return 'detected: ${byPath.join(', ')}';
      }

      final proc = await procKbdNames();
      if (proc.isNotEmpty) {
        return 'detected: ${proc.join(', ')}';
      }

      return 'not detected';
    } catch (_) {
      return 'probe unavailable';
    }
  }
}
