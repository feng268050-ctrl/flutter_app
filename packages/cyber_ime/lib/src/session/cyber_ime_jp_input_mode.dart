/// Soft JIS input mode (英数 / ひらがな / カタカナ).
///
/// Orthogonal to [CyberImeGlobalKind] (EN/ZH). Only applies when the regional
/// profile is [CyberImeRegionalProfile.jis].
enum CyberImeJpInputMode {
  /// Latin alphanumeric (英数) — KeyMap base/shift.
  english,

  /// Hiragana from KeyMap `kana` / `kanaShift` (Shift = small kana / を).
  hiragana,

  /// Katakana — same KeyMap kana slots, converted with [cyberImeToKatakana].
  katakana,
}

/// Hiragana (and voiced marks) → katakana. Non-hiragana code points unchanged.
String cyberImeToKatakana(String input) {
  final out = StringBuffer();
  for (final unit in input.runes) {
    if (unit >= 0x3041 && unit <= 0x3096) {
      out.writeCharCode(unit + 0x60);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}
