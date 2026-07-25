/// Physical keyboard presence + XKB layout (D15).
///
/// Backend: presence via `/dev/input/by-id`; layout via
/// `/var/lib/hal/keyboard.conf` (and/or `/etc/default/keyboard`).
///
/// **v1 apply:** [Keyboard.setLayout] persists the preference then restarts
/// `hmi.service` so XKB is re-read at init. The **App MUST
/// restore the previous route** after relaunch (persist last route and open
/// it on startup). HAL does not own navigation.
///
/// Concrete Linux type: [LinuxKeyboard] (exported from `hal/input.dart`).
library;

export 'package:cyber_hal/src/input/usb_hid_keyboard_probe.dart';

/// Portable keyboard API.
abstract class Keyboard {
  Future<bool> isPresent();

  Future<KeyboardLayout> getLayout();

  /// Persist layout preference (and optionally sync `/etc/default/keyboard`).
  ///
  /// When [restart] is true (default), also restarts `hmi.service`
  /// so XKB is re-read at init. Product Settings MAY call with `restart: false`
  /// then invoke [restartToApply] from its Restart action.
  /// App MUST restore the previous route after relaunch when restarting.
  Future<void> setLayout(KeyboardLayout layout, {bool restart = true});

  /// Restart HMI so a previously persisted layout is picked up by XKB.
  Future<void> restartToApply();

  Future<List<KeyboardLayout>> listLayouts();

  Future<void> dispose();
}

final class KeyboardLayout {
  const KeyboardLayout({
    required this.id,
    this.variant = '',
    this.options = '',
    this.model = 'pc105',
    this.displayName,
    this.softProfile = '',
  });

  /// XKB layout id (e.g. `us`, `ru`).
  final String id;
  final String variant;
  final String options;
  final String model;
  final String? displayName;

  /// Soft CyberIME profile id: `default` / `ansi` / `qwertz` / `azerty` / `jis`.
  /// Persisted as `profile=` in keyboard.conf (not sent to XKB).
  final String softProfile;

  KeyboardLayout copyWith({
    String? id,
    String? variant,
    String? options,
    String? model,
    String? displayName,
    String? softProfile,
  }) {
    return KeyboardLayout(
      id: id ?? this.id,
      variant: variant ?? this.variant,
      options: options ?? this.options,
      model: model ?? this.model,
      displayName: displayName ?? this.displayName,
      softProfile: softProfile ?? this.softProfile,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KeyboardLayout &&
        other.id == id &&
        other.variant == variant &&
        other.options == options &&
        other.model == model &&
        other.softProfile == softProfile;
  }

  @override
  int get hashCode => Object.hash(id, variant, options, model, softProfile);
}
