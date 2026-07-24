/// USB OTG port modes (debug / mtp / host).
library;

/// Persisted OTG role (`/var/lib/hal/usb-otg.conf` `mode=`).
enum UsbOtgMode {
  debug,
  mtp,
  host;

  String get confValue => name;

  static UsbOtgMode? tryParse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'debug':
      case 'usb-debug':
        return UsbOtgMode.debug;
      case 'mtp':
        return UsbOtgMode.mtp;
      case 'host':
        return UsbOtgMode.host;
      default:
        return null;
    }
  }
}

/// Board / product policy from `/etc/usb-otg.ini`.
class UsbOtgSupport {
  const UsbOtgSupport({
    this.debugOnly = false,
    this.autoHostSupport = false,
  });

  /// Force USB-SSH Debug; Settings offers no other modes.
  final bool debugOnly;

  /// Hardware can auto-detect host via ID and/or Type-C CC.
  final bool autoHostSupport;

  static bool parseBool(String? raw, {bool fallback = false}) {
    if (raw == null) {
      return fallback;
    }
    switch (raw.trim().toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return fallback;
    }
  }

  static UsbOtgSupport fromIniMap(Map<String, String> map) {
    return UsbOtgSupport(
      debugOnly: parseBool(map['debug_only']),
      autoHostSupport: parseBool(map['auto_host_support']),
    );
  }
}

/// Portable USB OTG controller (mode switch only; no attach/detach).
abstract class UsbOtg {
  /// Persisted mode (default [UsbOtgMode.debug] when conf missing).
  Future<UsbOtgMode> getMode();

  /// Persist + apply mode (writes `/var/lib/hal/usb-otg.conf` and starts services).
  Future<void> setMode(UsbOtgMode mode);

  /// Boot / udev reconcile per board policy + persisted mode.
  Future<void> apply();

  /// Reads `/etc/usb-otg.ini` (`debug_only`, `auto_host_support`).
  Future<UsbOtgSupport> getSupport();

  /// Modes offered in Settings (empty UI lock when [UsbOtgSupport.debugOnly]).
  ///
  /// `debug_only` → `[debug]` only.
  /// `auto_host_support` → debug, mtp.
  /// else → debug, mtp, host.
  Future<List<UsbOtgMode>> pickerModes();

  /// Fires after [setMode] / [apply] so UI can refresh labels.
  Stream<void> get updates;
}
