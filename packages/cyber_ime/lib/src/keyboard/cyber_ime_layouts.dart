import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_code.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_map.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_typewriter_layouts.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';

/// Factory for Keyboard A / B layouts.
///
/// - [CyberImeRegionalProfile.defaultSoft]: original CyberIME phone pad
/// - ANSI: typewriter block + Ctrl/Alt/Space (Shift layer via KeyMap; no F/NumPad)
/// - QWERTZ / AZERTY: ISO typewriter + Ctrl/Alt/Space/AltGr (no F-row / NumPad)
/// - JIS: typewriter block + AltGr (no F-row / NumPad)
abstract final class CyberImeLayouts {
  /// Keyboard A letter layer for the active (or explicit) regional profile.
  static CyberImeLayout letters({
    CyberImeRegionalProfile? profile,
    CyberImeBottomRowProfile bottomRow = CyberImeBottomRowProfile.defaults,
    CyberImeKeyboardKind kind = CyberImeKeyboardKind.englishGlobal,
  }) {
    final regional =
        profile ?? CyberImeRegionalLayoutRegistry.provider.profile;
    if (regional == CyberImeRegionalProfile.defaultSoft) {
      return _phoneDefault(bottomRow: bottomRow, kind: kind);
    }
    return CyberImeTypewriterLayouts.build(
      regional,
      kind: kind,
      bottomRow: cyberImeBottomRowKeys(bottomRow),
    );
  }

  /// Backward-compatible alias.
  static CyberImeLayout qwerty({
    CyberImeBottomRowProfile bottomRow = CyberImeBottomRowProfile.defaults,
    CyberImeKeyboardKind kind = CyberImeKeyboardKind.englishGlobal,
    CyberImeRegionalProfile? profile,
  }) {
    return letters(profile: profile, bottomRow: bottomRow, kind: kind);
  }

  /// Original CyberIME phone QWERTY (3 letter rows + bottom) with digit secondaries.
  static CyberImeLayout _phoneDefault({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    const profile = CyberImeRegionalProfile.ansi;
    const row1Codes = <CyberImeKeyCode>[
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
    const row2Codes = <CyberImeKeyCode>[
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
    const row3Codes = <CyberImeKeyCode>[
      CyberImeKeyCode.keyZ,
      CyberImeKeyCode.keyX,
      CyberImeKeyCode.keyC,
      CyberImeKeyCode.keyV,
      CyberImeKeyCode.keyB,
      CyberImeKeyCode.keyN,
      CyberImeKeyCode.keyM,
    ];
    const row1Secondaries = <CyberImeKeyCode>[
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
    const row2Hints = ['~', '!', '@', '#', '%', '"', "'", '*', '?'];
    const row3Hints = ['(', ')', '-', '_', ':', ';', '/'];

    CyberImeKeyDef letter(CyberImeKeyCode code, String? secondary) {
      final primary = CyberImeKeyMaps.resolve(profile, code, shiftOn: true);
      return CyberImeKeyDef(
        id: CyberImeKeyId.letter,
        primary: primary,
        secondary: secondary,
        isLetter: true,
        keyCode: code,
      );
    }

    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (var i = 0; i < row1Codes.length; i++)
            letter(
              row1Codes[i],
              CyberImeKeyMaps.resolve(
                profile,
                row1Secondaries[i],
                shiftOn: false,
              ),
            ),
        ]),
        CyberImeKeyboardRow(
          [
            for (var i = 0; i < row2Codes.length; i++)
              letter(row2Codes[i], row2Hints[i]),
          ],
          leadingInsetWeight: 0.5,
          trailingInsetWeight: 0.5,
        ),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.shift,
            primary: '⇧',
            widthWeight: 1.4,
          ),
          for (var i = 0; i < row3Codes.length; i++)
            letter(row3Codes[i], row3Hints[i]),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.4,
          ),
        ]),
        CyberImeKeyboardRow(cyberImeBottomRowKeys(bottomRow)),
      ],
    );
  }

  static CyberImeLayout symbolsPrimary() {
    CyberImeKeyDef digit(String v) =>
        CyberImeKeyDef(id: CyberImeKeyId.digit, primary: v);
    CyberImeKeyDef symbol(String v) =>
        CyberImeKeyDef(id: CyberImeKeyId.custom, primary: v);

    return CyberImeLayout(
      kind: CyberImeKeyboardKind.symbolsPrimary,
      rows: [
        CyberImeKeyboardRow([
          for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
            digit(d),
        ]),
        CyberImeKeyboardRow([
          symbol('-'),
          symbol('/'),
          symbol(':'),
          symbol(';'),
          symbol('('),
          symbol(')'),
          symbol(r'$'),
          symbol('&'),
          const CyberImeKeyDef(id: CyberImeKeyId.at, primary: '@'),
          symbol('"'),
        ]),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.symbolsMore,
            primary: '#+=',
            widthWeight: 1.4,
          ),
          symbol(','),
          symbol('.'),
          symbol('?'),
          symbol('!'),
          const CyberImeKeyDef(
            id: CyberImeKeyId.custom,
            primary: "'",
            secondary: '`',
          ),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.2,
          ),
        ]),
        CyberImeKeyboardRow(_symbolBottomRow()),
      ],
    );
  }

  static CyberImeLayout symbolsExtended() {
    CyberImeKeyDef symbol(String v) =>
        CyberImeKeyDef(id: CyberImeKeyId.custom, primary: v);

    return CyberImeLayout(
      kind: CyberImeKeyboardKind.symbolsExtended,
      rows: [
        CyberImeKeyboardRow([
          for (final s in ['[', ']', '{', '}', '#', '%', '^', '*', '+', '='])
            symbol(s),
        ]),
        CyberImeKeyboardRow([
          for (final s in ['_', r'\', '|', '~', '<', '>', '€', '£', '¥', '•'])
            symbol(s),
        ]),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.modeSwitch,
            primary: '123',
            widthWeight: 1.4,
          ),
          symbol(','),
          symbol('.'),
          symbol('?'),
          symbol('!'),
          const CyberImeKeyDef(
            id: CyberImeKeyId.custom,
            primary: "'",
            secondary: '`',
          ),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.2,
          ),
        ]),
        CyberImeKeyboardRow(_symbolBottomRow()),
      ],
    );
  }

  /// Keyboard B — dedicated numeric pad (no abc switch).
  static CyberImeLayout numericDedicated() {
    return const CyberImeLayout(
      kind: CyberImeKeyboardKind.numericDedicated,
      rows: [
        CyberImeKeyboardRow([
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '1'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '2'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '3'),
          CyberImeKeyDef(id: CyberImeKeyId.backspace, primary: '⌫'),
        ]),
        CyberImeKeyboardRow([
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '4'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '5'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '6'),
          CyberImeKeyDef(id: CyberImeKeyId.clear, primary: 'C'),
        ]),
        CyberImeKeyboardRow([
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '7'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '8'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '9'),
          CyberImeKeyDef(id: CyberImeKeyId.minus, primary: '-'),
        ]),
        CyberImeKeyboardRow([
          CyberImeKeyDef(id: CyberImeKeyId.decimalPeriod, primary: '.'),
          CyberImeKeyDef(id: CyberImeKeyId.digit, primary: '0'),
          CyberImeKeyDef(id: CyberImeKeyId.custom, primary: '00'),
          CyberImeKeyDef(id: CyberImeKeyId.enter, primary: '⏎'),
        ]),
      ],
    );
  }

  static List<CyberImeKeyDef> _symbolBottomRow() => const [
        CyberImeKeyDef(
          id: CyberImeKeyId.modeSwitch,
          primary: 'ABC',
          widthWeight: 1.4,
        ),
        CyberImeKeyDef(id: CyberImeKeyId.space, primary: ' ', widthWeight: 4),
        CyberImeKeyDef(id: CyberImeKeyId.enter, primary: '⏎', widthWeight: 1.4),
      ];
}
