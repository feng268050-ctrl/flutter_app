import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_soft_layouts.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';

/// Factory for Keyboard A / B layouts.
///
/// Keyboard A letter layouts are phone soft pads from [CyberImeSoftLayouts]
/// (QWERTY / QWERTZ / AZERTY / JIS). Symbol layers stay shared phone pages.
abstract final class CyberImeLayouts {
  /// Keyboard A letter layer for the active (or explicit) regional profile.
  static CyberImeLayout letters({
    CyberImeRegionalProfile? profile,
    CyberImeBottomRowProfile bottomRow = CyberImeBottomRowProfile.defaults,
    CyberImeKeyboardKind kind = CyberImeKeyboardKind.englishGlobal,
  }) {
    final regional =
        profile ?? CyberImeRegionalLayoutRegistry.provider.profile;
    return CyberImeSoftLayouts.letters(
      regional,
      bottomRow: bottomRow,
      kind: kind,
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

  static CyberImeLayout symbolsPrimary({
    CyberImeRegionalProfile? profile,
  }) {
    final regional =
        profile ?? CyberImeRegionalLayoutRegistry.provider.profile;
    final currency = switch (regional) {
      CyberImeRegionalProfile.qwerty => r'$',
      CyberImeRegionalProfile.qwertz ||
      CyberImeRegionalProfile.azerty =>
        '€',
      CyberImeRegionalProfile.jis => '￥',
    };

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
          symbol(currency),
          symbol('&'),
          const CyberImeKeyDef(id: CyberImeKeyId.at, primary: '@'),
          symbol('"'),
        ]),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.symbolsMore,
            primary: '#+=',
            widthWeight: 1.5,
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
            widthWeight: 1.5,
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
            widthWeight: 1.5,
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
            widthWeight: 1.5,
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
          widthWeight: 1.5,
        ),
        CyberImeKeyDef(id: CyberImeKeyId.space, primary: ' ', widthWeight: 5),
        CyberImeKeyDef(id: CyberImeKeyId.enter, primary: '⏎', widthWeight: 1.8),
      ];
}
