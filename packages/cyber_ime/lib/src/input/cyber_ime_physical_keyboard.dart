/// App-injected physical keyboard presence for soft-IME suppression.
///
/// CyberIME does **not** probe hardware. Product Apps register a detector that
/// typically forwards to `cyber_hal` [`Keyboard.isPresent`]. When unregistered,
/// presence is treated as false (soft IME may show).
library;

/// Detects whether a physical keyboard is available for typing.
abstract class CyberImePhysicalKeyboardDetector {
  Future<bool> get isPresent;
}

/// Forwards to an App/HAL callback (preferred production wiring).
class CyberImeCallbackPhysicalKeyboardDetector
    implements CyberImePhysicalKeyboardDetector {
  const CyberImeCallbackPhysicalKeyboardDetector(this._isPresent);

  final Future<bool> Function() _isPresent;

  @override
  Future<bool> get isPresent => _isPresent();
}

/// Fixed answer for widget tests / host stubs.
class CyberImeFixedPhysicalKeyboardDetector
    implements CyberImePhysicalKeyboardDetector {
  const CyberImeFixedPhysicalKeyboardDetector(this.present);

  final bool present;

  @override
  Future<bool> get isPresent async => present;
}

/// Registration for physical-keyboard presence (App wires HAL).
abstract final class CyberImePhysicalKeyboard {
  static CyberImePhysicalKeyboardDetector? _detector;

  /// Register App/HAL detector. Pass `null` to clear (soft IME always allowed).
  static void register(CyberImePhysicalKeyboardDetector? detector) {
    _detector = detector;
  }

  static CyberImePhysicalKeyboardDetector? get detector => _detector;

  /// `false` when no detector is registered.
  static Future<bool> isPresent() async {
    final d = _detector;
    if (d == null) {
      return false;
    }
    return d.isPresent;
  }
}
