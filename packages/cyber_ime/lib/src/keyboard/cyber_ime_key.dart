/// Key identifiers for CyberIME layouts.
enum CyberImeKeyId {
  letter,
  digit,
  custom,
  shift,
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
}

/// One key on a CyberIME layout.
class CyberImeKeyDef {
  const CyberImeKeyDef({
    required this.id,
    required this.primary,
    this.secondary,
    this.widthWeight = 1,
    this.isLetter = false,
  });

  final CyberImeKeyId id;
  final String primary;
  final String? secondary;
  final double widthWeight;
  final bool isLetter;
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
