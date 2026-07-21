import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';

/// Factory for Keyboard A / B layouts (lws-ui KeyboardLayouts port).
abstract final class CyberImeLayouts {
  static CyberImeLayout qwerty({
    CyberImeBottomRowProfile bottomRow = CyberImeBottomRowProfile.defaults,
    CyberImeKeyboardKind kind = CyberImeKeyboardKind.englishGlobal,
  }) {
    const row1Secondaries = [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
    ];
    const row2Secondaries = [
      '~', '!', '@', '#', '%', '"', "'", '*', '?',
    ];
    const row3Secondaries = ['(', ')', '-', '_', ':', ';', '/'];
    const letters1 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    const letters2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    const letters3 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];

    CyberImeKeyDef letter(String primary, String secondary) => CyberImeKeyDef(
          id: CyberImeKeyId.letter,
          primary: primary,
          secondary: secondary,
          isLetter: true,
        );

    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (var i = 0; i < letters1.length; i++)
            letter(letters1[i], row1Secondaries[i]),
        ]),
        CyberImeKeyboardRow(
          [
            for (var i = 0; i < letters2.length; i++)
              letter(letters2[i], row2Secondaries[i]),
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
          for (var i = 0; i < letters3.length; i++)
            letter(letters3[i], row3Secondaries[i]),
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
