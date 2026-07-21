/// Logical typewriter key identity shared by soft layouts and KeyMap tables.
///
/// Positions follow US ANSI geometry as the identity (same convention as XKB
/// keycodes for the alphanumerics block). F1–F12 and keypad keys are **not**
/// modeled — hardware / flutter-pi / XKB owns those.
enum CyberImeKeyCode {
  // Number row (physical positions)
  grave,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
  digit0,
  minus,
  equal,

  // Letter rows (physical positions; US labels as identity names)
  keyQ,
  keyW,
  keyE,
  keyR,
  keyT,
  keyY,
  keyU,
  keyI,
  keyO,
  keyP,
  keyA,
  keyS,
  keyD,
  keyF,
  keyG,
  keyH,
  keyJ,
  keyK,
  keyL,
  keyZ,
  keyX,
  keyC,
  keyV,
  keyB,
  keyN,
  keyM,

  // Punctuation / region-specific positions
  bracketLeft,
  bracketRight,
  backslash,
  semicolon,
  quote,
  comma,
  period,
  slash,
  intlBackslash,
  yen,
}
