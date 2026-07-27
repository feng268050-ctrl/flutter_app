import 'package:cyber_ime/src/keyboard/cyber_ime_key_code.dart';

/// Key identifiers for CyberIME layouts.
enum CyberImeKeyId {
  letter,
  digit,
  custom,
  shift,
  capsLock,
  tab,
  control,
  alt,
  altGr,
  backspace,
  clear,
  space,
  enter,
  modeSwitch,
  symbolsMore,
  at,
  commaPeriod,
  minus,
  decimalPeriod,
  passwordReveal,

  /// JIS 半角/全角 — toggles 英数 ↔ ひらがな.
  hankakuZenkaku,

  /// JIS 無変換 — force 英数 mode (no composition engine).
  muhenkan,

  /// JIS 変換 — reserved (no candidate UI in v1).
  henkan,

  /// JIS カタカナ/ひらがな — cycle kana modes.
  kanaToggle,

  /// Soft JIS language toggle — 英数 ↔ ローマ字 (あ / ABC).
  languageToggle,
}

/// One key on a CyberIME layout.
class CyberImeKeyDef {
  const CyberImeKeyDef({
    required this.id,
    required this.primary,
    this.secondary,
    this.widthWeight = 1,
    this.isLetter = false,
    this.keyCode,
    this.rowSpan = 1,
    this.longPressOptions,
  });

  final CyberImeKeyId id;
  final String primary;
  final String? secondary;
  final double widthWeight;
  final bool isLetter;

  /// Optional typewriter KeyCode (letter keys built from KeyMap).
  final CyberImeKeyCode? keyCode;

  /// Vertical span in layout rows (ISO L-Enter uses `2`).
  final int rowSpan;

  /// Explicit long-press popup options (accents). When set, overrides default
  /// case-twin popup construction for letters.
  final List<String>? longPressOptions;
}

/// One row of keys.
class CyberImeKeyboardRow {
  const CyberImeKeyboardRow(
    this.keys, {
    this.leadingInsetWeight = 0,
    this.trailingInsetWeight = 0,
  });

  final List<CyberImeKeyDef> keys;
  final double leadingInsetWeight;
  final double trailingInsetWeight;
}
