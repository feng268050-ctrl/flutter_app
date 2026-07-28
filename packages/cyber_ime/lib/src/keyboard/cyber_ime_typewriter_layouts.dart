import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_code.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_map.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';

/// Typewriter-block geometry (60% alphanumeric area only).
///
/// No F-row, no navigation cluster, no right-hand NumPad. Control keys that
/// exist on physical boards (Tab / Caps / Shift / Ctrl / Alt / AltGr / Space /
/// Enter / Backspace) are kept on the soft layout. Form-factor differs per
/// profile: ANSI Enter + long left Shift + Ctrl/Alt/Space bottom; ISO short
/// left Shift + intl key + Ctrl/Alt/Space/AltGr bottom; JIS ¥ / 半角全角 +
/// 無変換/変換/かな bottom.
abstract final class CyberImeTypewriterLayouts {
  static CyberImeLayout build(
    CyberImeRegionalProfile profile, {
    required CyberImeKeyboardKind kind,
    required List<CyberImeKeyDef> bottomRow,
  }) {
    final mapProfile = profile;
    final letterRows = switch (profile) {
      CyberImeRegionalProfile.qwerty => _ansiUs(mapProfile),
      CyberImeRegionalProfile.qwertz => _isoDe(mapProfile),
      CyberImeRegionalProfile.azerty => _isoFr(mapProfile),
      CyberImeRegionalProfile.jis => _jisJp(mapProfile),
    };
    final bottom = switch (profile) {
      CyberImeRegionalProfile.qwerty => _ansiModifierRow(bottomRow),
      CyberImeRegionalProfile.qwertz ||
      CyberImeRegionalProfile.azerty =>
        _isoModifierRow(bottomRow),
      CyberImeRegionalProfile.jis => _jisModifierRow(bottomRow),
    };
    return CyberImeLayout(
      kind: kind,
      rows: [
        ...letterRows,
        CyberImeKeyboardRow(bottom),
      ],
    );
  }

  /// US ANSI modifier row: Ctrl | Alt | Space | Alt | Ctrl (+ field extras).
  ///
  /// No AltGr — second function is Shift layer via KeyMap + long-press slide.
  /// Enter stays on the home row (ANSI horizontal Enter). Field extras such as
  /// password reveal are preserved between Space and the right Ctrl.
  /// Typewriter bottoms omit the phone-pad `.` / `,` key; Space is widened.
  static List<CyberImeKeyDef> _ansiModifierRow(List<CyberImeKeyDef> fieldBottom) {
    final extras = _fieldExtras(fieldBottom);
    return [
      _ctrl(1.25),
      _alt(1.25),
      const CyberImeKeyDef(
        id: CyberImeKeyId.space,
        primary: ' ',
        widthWeight: 5.5,
      ),
      ...extras,
      _alt(1.25),
      _ctrl(1.25),
    ];
  }

  /// ISO modifier row: Ctrl | Alt | Space | AltGr | Ctrl (+ field extras).
  ///
  /// Matches ISO bottom (no Win / Menu). AltGr is the third character layer;
  /// Shift layer remains KeyMap `shift` + long-press slide.
  static List<CyberImeKeyDef> _isoModifierRow(List<CyberImeKeyDef> fieldBottom) {
    final extras = _fieldExtras(fieldBottom);
    return [
      _ctrl(1.2),
      _alt(1.2),
      const CyberImeKeyDef(
        id: CyberImeKeyId.space,
        primary: ' ',
        widthWeight: 4.8,
      ),
      _altGr(1.35),
      ...extras,
      _ctrl(1.2),
    ];
  }

  static List<CyberImeKeyDef> _fieldExtras(List<CyberImeKeyDef> fieldBottom) {
    return fieldBottom
        .where(
          (k) =>
              k.id != CyberImeKeyId.modeSwitch &&
              k.id != CyberImeKeyId.space &&
              k.id != CyberImeKeyId.enter &&
              k.id != CyberImeKeyId.altGr &&
              k.id != CyberImeKeyId.control &&
              k.id != CyberImeKeyId.alt &&
              k.id != CyberImeKeyId.muhenkan &&
              k.id != CyberImeKeyId.henkan &&
              k.id != CyberImeKeyId.kanaToggle &&
              // Typewriter letter rows already have `.` / `,`; drop phone-pad dup.
              k.id != CyberImeKeyId.commaPeriod,
        )
        .toList();
  }

  /// JIS modifier row: Ctrl | Alt | 無変換 | Space | 変換 | かな | Ctrl.
  ///
  /// No Win/Menu. No AltGr (JIS soft uses Shift + jp input mode instead).
  static List<CyberImeKeyDef> _jisModifierRow(List<CyberImeKeyDef> fieldBottom) {
    final extras = _fieldExtras(fieldBottom);
    return [
      _ctrl(1.0),
      _alt(1.0),
      const CyberImeKeyDef(
        id: CyberImeKeyId.muhenkan,
        primary: '無変換',
        widthWeight: 1.35,
      ),
      const CyberImeKeyDef(
        id: CyberImeKeyId.space,
        primary: ' ',
        widthWeight: 4.0,
      ),
      const CyberImeKeyDef(
        id: CyberImeKeyId.henkan,
        primary: '変換',
        widthWeight: 1.2,
      ),
      const CyberImeKeyDef(
        id: CyberImeKeyId.kanaToggle,
        primary: 'カナ',
        secondary: 'かな',
        widthWeight: 1.35,
      ),
      ...extras,
      _ctrl(1.0),
    ];
  }

  /// ANSI US — number/symbol row, QWERTY, Tab/Caps/Shift/Enter, long left Shift.
  static List<CyberImeKeyboardRow> _ansiUs(CyberImeRegionalProfile p) => [
        CyberImeKeyboardRow([
          _char(p, CyberImeKeyCode.grave),
          for (final c in _digits) _char(p, c),
          _char(p, CyberImeKeyCode.minus),
          _char(p, CyberImeKeyCode.equal),
          _backspace(1.8),
        ]),
        CyberImeKeyboardRow([
          _tab(1.4),
          for (final c in _rowQwerty) _char(p, c),
          _char(p, CyberImeKeyCode.bracketLeft),
          _char(p, CyberImeKeyCode.bracketRight),
          _char(p, CyberImeKeyCode.backslash, width: 1.4),
        ]),
        CyberImeKeyboardRow([
          _caps(1.7),
          for (final c in _rowAsdf) _char(p, c),
          _char(p, CyberImeKeyCode.semicolon),
          _char(p, CyberImeKeyCode.quote),
          _enter(1.9),
        ]),
        CyberImeKeyboardRow([
          _shift(2.2),
          for (final c in _rowZxcv) _char(p, c),
          _char(p, CyberImeKeyCode.comma),
          _char(p, CyberImeKeyCode.period),
          _char(p, CyberImeKeyCode.slash),
          _shift(2.2),
        ]),
      ];

  /// ISO DE QWERTZ — short left Shift + `<` intl; ü/+ ; ö/ä/# ;
  /// one ISO L-Enter (`rowSpan: 2`) on the letter row (no F-row / NumPad).
  static List<CyberImeKeyboardRow> _isoDe(CyberImeRegionalProfile p) => [
        CyberImeKeyboardRow([
          _char(p, CyberImeKeyCode.grave),
          for (final c in _digits) _char(p, c),
          _char(p, CyberImeKeyCode.minus), // ß ?
          _char(p, CyberImeKeyCode.equal), // ´ `
          _backspace(1.8),
        ]),
        CyberImeKeyboardRow([
          _tab(1.4),
          for (final c in _rowQwerty) _char(p, c), // Z via KeyMap on keyY
          _char(p, CyberImeKeyCode.bracketLeft), // ü Ü
          _char(p, CyberImeKeyCode.bracketRight), // + * ~
          _enter(1.5, rowSpan: 2),
        ]),
        CyberImeKeyboardRow([
          _caps(1.8),
          for (final c in _rowAsdf) _char(p, c),
          _char(p, CyberImeKeyCode.semicolon), // ö Ö
          _char(p, CyberImeKeyCode.quote), // ä Ä
          _char(p, CyberImeKeyCode.backslash), // # '
        ]),
        CyberImeKeyboardRow([
          _shift(1.25),
          _char(p, CyberImeKeyCode.intlBackslash), // < > |
          for (final c in _rowZxcv) _char(p, c), // Y via KeyMap on keyZ
          _char(p, CyberImeKeyCode.comma),
          _char(p, CyberImeKeyCode.period),
          _char(p, CyberImeKeyCode.slash), // - _
          _shift(2.15),
        ]),
      ];

  /// ISO FR AZERTY — A/Z on top row; M on home row; short left Shift + `<`.
  static List<CyberImeKeyboardRow> _isoFr(CyberImeRegionalProfile p) => [
        CyberImeKeyboardRow([
          _char(p, CyberImeKeyCode.grave), // ²
          for (final c in _digits) _char(p, c),
          _char(p, CyberImeKeyCode.minus),
          _char(p, CyberImeKeyCode.equal),
          _backspace(1.8),
        ]),
        CyberImeKeyboardRow([
          _tab(1.4),
          for (final c in _rowQwerty) _char(p, c), // → A Z E R T Y …
          _char(p, CyberImeKeyCode.bracketLeft), // ^
          _char(p, CyberImeKeyCode.bracketRight), // $
        ]),
        CyberImeKeyboardRow([
          _caps(1.7),
          for (final c in _rowAsdf) _char(p, c), // → Q S D F …
          _char(p, CyberImeKeyCode.semicolon), // m
          _char(p, CyberImeKeyCode.quote), // ù
          _char(p, CyberImeKeyCode.backslash), // *
          _enter(1.6),
        ]),
        CyberImeKeyboardRow([
          _shift(1.3),
          _char(p, CyberImeKeyCode.intlBackslash), // < >
          for (final c in [
            CyberImeKeyCode.keyZ, // w
            CyberImeKeyCode.keyX,
            CyberImeKeyCode.keyC,
            CyberImeKeyCode.keyV,
            CyberImeKeyCode.keyB,
            CyberImeKeyCode.keyN,
          ])
            _char(p, c),
          _char(p, CyberImeKeyCode.keyM), // ,
          _char(p, CyberImeKeyCode.comma), // ;
          _char(p, CyberImeKeyCode.period), // :
          _char(p, CyberImeKeyCode.slash), // !
          _shift(1.6),
        ]),
      ];

  /// JIS JP — 半角/全角 + ¥; @ [ on top letter row; ] on home; \ on shift row.
  static List<CyberImeKeyboardRow> _jisJp(CyberImeRegionalProfile p) => [
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.hankakuZenkaku,
            primary: '半/全',
            widthWeight: 1.3,
          ),
          for (final c in _digits) _char(p, c),
          _char(p, CyberImeKeyCode.minus),
          _char(p, CyberImeKeyCode.equal),
          _char(p, CyberImeKeyCode.yen),
          _backspace(1.5),
        ]),
        CyberImeKeyboardRow([
          _tab(1.4),
          for (final c in _rowQwerty) _char(p, c),
          _char(p, CyberImeKeyCode.bracketLeft), // @
          _char(p, CyberImeKeyCode.bracketRight), // [
        ]),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.capsLock,
            primary: '英数',
            widthWeight: 1.7,
          ),
          for (final c in _rowAsdf) _char(p, c),
          _char(p, CyberImeKeyCode.semicolon),
          _char(p, CyberImeKeyCode.quote),
          _char(p, CyberImeKeyCode.backslash), // ]
          _enter(1.6),
        ]),
        CyberImeKeyboardRow([
          _shift(1.5),
          for (final c in _rowZxcv) _char(p, c),
          _char(p, CyberImeKeyCode.comma),
          _char(p, CyberImeKeyCode.period),
          _char(p, CyberImeKeyCode.slash),
          _char(p, CyberImeKeyCode.intlBackslash), // \ _
          _shift(1.8),
        ]),
      ];

  static const _digits = <CyberImeKeyCode>[
    CyberImeKeyCode.digit1,
    CyberImeKeyCode.digit2,
    CyberImeKeyCode.digit3,
    CyberImeKeyCode.digit4,
    CyberImeKeyCode.digit5,
    CyberImeKeyCode.digit6,
    CyberImeKeyCode.digit7,
    CyberImeKeyCode.digit8,
    CyberImeKeyCode.digit9,
    CyberImeKeyCode.digit0,
  ];

  static const _rowQwerty = <CyberImeKeyCode>[
    CyberImeKeyCode.keyQ,
    CyberImeKeyCode.keyW,
    CyberImeKeyCode.keyE,
    CyberImeKeyCode.keyR,
    CyberImeKeyCode.keyT,
    CyberImeKeyCode.keyY,
    CyberImeKeyCode.keyU,
    CyberImeKeyCode.keyI,
    CyberImeKeyCode.keyO,
    CyberImeKeyCode.keyP,
  ];

  static const _rowAsdf = <CyberImeKeyCode>[
    CyberImeKeyCode.keyA,
    CyberImeKeyCode.keyS,
    CyberImeKeyCode.keyD,
    CyberImeKeyCode.keyF,
    CyberImeKeyCode.keyG,
    CyberImeKeyCode.keyH,
    CyberImeKeyCode.keyJ,
    CyberImeKeyCode.keyK,
    CyberImeKeyCode.keyL,
  ];

  static const _rowZxcv = <CyberImeKeyCode>[
    CyberImeKeyCode.keyZ,
    CyberImeKeyCode.keyX,
    CyberImeKeyCode.keyC,
    CyberImeKeyCode.keyV,
    CyberImeKeyCode.keyB,
    CyberImeKeyCode.keyN,
    CyberImeKeyCode.keyM,
  ];

  static CyberImeKeyDef _char(
    CyberImeRegionalProfile profile,
    CyberImeKeyCode code, {
    double width = 1,
  }) {
    final level = CyberImeKeyMaps.level(profile, code);
    final base = level.base;
    final shift = level.shift ?? base;
    final altGr = level.altGr;
    // True letter only when Shift is a case twin (e/E). Accented glyphs with a
    // non-case Shift (ù→%, é→2) stay on the symbol path so Shift shows as
    // secondary.
    final isLetter = base.length == 1 &&
        _isAlphabetic(base) &&
        _isCasePair(base, shift);
    // KeyCode + normal/shift (+ optional AltGr). Soft commit resolves via KeyMap.
    // secondary on symbols is the Shift layer (long-press slide popup).
    // secondary on letters is AltGr when present (third option in popup).
    if (isLetter) {
      return CyberImeKeyDef(
        id: CyberImeKeyId.letter,
        primary: shift,
        secondary: (altGr != null && altGr.isNotEmpty) ? altGr : null,
        widthWeight: width,
        isLetter: true,
        keyCode: code,
      );
    }
    // Always attach Shift layer when it differs; else AltGr as secondary hint.
    final secondary = (shift != base)
        ? shift
        : ((altGr != null && altGr.isNotEmpty) ? altGr : null);
    return CyberImeKeyDef(
      id: CyberImeKeyId.custom,
      primary: base,
      secondary: secondary,
      widthWeight: width,
      isLetter: false,
      keyCode: code,
    );
  }

  static CyberImeKeyDef _tab(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.tab,
        primary: 'Tab',
        widthWeight: w,
      );

  static CyberImeKeyDef _caps(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.capsLock,
        primary: 'Caps',
        widthWeight: w,
      );

  static CyberImeKeyDef _shift(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.shift,
        primary: '⇧',
        widthWeight: w,
      );

  static CyberImeKeyDef _ctrl(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.control,
        primary: 'Ctrl',
        widthWeight: w,
      );

  static CyberImeKeyDef _alt(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.alt,
        primary: 'Alt',
        widthWeight: w,
      );

  static CyberImeKeyDef _altGr(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.altGr,
        primary: 'AltGr',
        widthWeight: w,
      );

  static CyberImeKeyDef _backspace(double w) => CyberImeKeyDef(
        id: CyberImeKeyId.backspace,
        primary: '⌫',
        widthWeight: w,
      );

  static CyberImeKeyDef _enter(double w, {int rowSpan = 1}) => CyberImeKeyDef(
        id: CyberImeKeyId.enter,
        primary: '⏎',
        widthWeight: w,
        rowSpan: rowSpan,
      );

  static bool _isAlphabetic(String s) {
    if (s.length != 1) return false;
    return RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]').hasMatch(s);
  }

  static bool _isCasePair(String base, String shift) {
    if (base.length != 1 || shift.length != 1) return false;
    return base.toLowerCase() == shift.toLowerCase();
  }
}
