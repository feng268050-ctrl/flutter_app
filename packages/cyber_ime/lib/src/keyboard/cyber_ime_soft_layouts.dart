import 'package:cyber_ime/src/field/cyber_ime_bottom_row_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';

/// Phone soft Keyboard A letter layouts shared by panel + Settings preview.
///
/// Three letter rows + bottom function row. No number row, F-keys, Tab/Caps,
/// Ctrl/Alt/AltGr, typewriter Enter, or NumPad.
abstract final class CyberImeSoftLayouts {
  static CyberImeLayout letters(
    CyberImeRegionalProfile profile, {
    CyberImeBottomRowProfile bottomRow = CyberImeBottomRowProfile.defaults,
    CyberImeKeyboardKind kind = CyberImeKeyboardKind.englishGlobal,
  }) {
    return switch (profile) {
      CyberImeRegionalProfile.qwerty => _qwerty(bottomRow: bottomRow, kind: kind),
      CyberImeRegionalProfile.qwertz => _qwertz(bottomRow: bottomRow, kind: kind),
      CyberImeRegionalProfile.azerty => _azerty(bottomRow: bottomRow, kind: kind),
      CyberImeRegionalProfile.jis => _jis(bottomRow: bottomRow, kind: kind),
    };
  }

  static CyberImeKeyDef _letter(
    String ch, {
    List<String>? longPressOptions,
  }) {
    return CyberImeKeyDef(
      id: CyberImeKeyId.letter,
      primary: ch.toUpperCase(),
      isLetter: true,
      longPressOptions: longPressOptions,
    );
  }

  static List<CyberImeKeyDef> _bottom(
    CyberImeBottomRowProfile bottomRow, {
    bool includeLanguage = false,
  }) {
    return cyberImeSoftBottomRowKeys(
      bottomRow,
      includeLanguageToggle: includeLanguage,
    );
  }

  static CyberImeLayout _qwerty({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (final c in 'QWERTYUIOP'.split('')) _letter(c),
        ]),
        CyberImeKeyboardRow(
          [for (final c in 'ASDFGHJKL'.split('')) _letter(c)],
          leadingInsetWeight: 0.5,
          trailingInsetWeight: 0.5,
        ),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.shift,
            primary: '⇧',
            widthWeight: 1.5,
          ),
          for (final c in 'ZXCVBNM'.split('')) _letter(c),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.5,
          ),
        ]),
        CyberImeKeyboardRow(_bottom(bottomRow)),
      ],
    );
  }

  static CyberImeLayout _qwertz({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (final c in 'QWERTZUIOP'.split(''))
            _letter(
              c,
              longPressOptions: switch (c) {
                'U' => const ['u', 'ü', 'U', 'Ü'],
                'O' => const ['o', 'ö', 'O', 'Ö'],
                _ => null,
              },
            ),
        ]),
        CyberImeKeyboardRow(
          [
            for (final c in 'ASDFGHJKL'.split(''))
              _letter(
                c,
                longPressOptions: switch (c) {
                  'A' => const ['a', 'ä', 'A', 'Ä'],
                  'S' => const ['s', 'ß', 'S', 'ẞ'],
                  _ => null,
                },
              ),
          ],
          leadingInsetWeight: 0.5,
          trailingInsetWeight: 0.5,
        ),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.shift,
            primary: '⇧',
            widthWeight: 1.5,
          ),
          for (final c in 'YXCVBNM'.split('')) _letter(c),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.5,
          ),
        ]),
        CyberImeKeyboardRow(_bottom(bottomRow)),
      ],
    );
  }

  static CyberImeLayout _azerty({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (final c in 'AZERTYUIOP'.split(''))
            _letter(
              c,
              longPressOptions: switch (c) {
                'A' => const ['a', 'à', 'â', 'æ', 'A', 'À', 'Â', 'Æ'],
                'E' => const [
                    'e',
                    'é',
                    'è',
                    'ê',
                    'ë',
                    'E',
                    'É',
                    'È',
                    'Ê',
                    'Ë',
                  ],
                'O' => const ['o', 'ô', 'œ', 'O', 'Ô', 'Œ'],
                _ => null,
              },
            ),
        ]),
        CyberImeKeyboardRow([
          for (final c in 'QSDFGHJKLM'.split(''))
            _letter(
              c,
              longPressOptions: c == 'C' ? const ['c', 'ç', 'C', 'Ç'] : null,
            ),
        ]),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.shift,
            primary: '⇧',
            widthWeight: 1.5,
          ),
          for (final c in 'WXCVBN'.split(''))
            _letter(
              c,
              longPressOptions: c == 'C' ? const ['c', 'ç', 'C', 'Ç'] : null,
            ),
          const CyberImeKeyDef(
            id: CyberImeKeyId.custom,
            primary: "'",
            widthWeight: 1,
          ),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.5,
          ),
        ]),
        CyberImeKeyboardRow(_bottom(bottomRow)),
      ],
    );
  }

  static CyberImeLayout _jis({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (final c in 'QWERTYUIOP'.split('')) _letter(c),
        ]),
        CyberImeKeyboardRow(
          [for (final c in 'ASDFGHJKL'.split('')) _letter(c)],
          leadingInsetWeight: 0.5,
          trailingInsetWeight: 0.5,
        ),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.shift,
            primary: '⇧',
            widthWeight: 1.5,
          ),
          for (final c in 'ZXCVBNM'.split('')) _letter(c),
          const CyberImeKeyDef(
            id: CyberImeKeyId.backspace,
            primary: '⌫',
            widthWeight: 1.5,
          ),
        ]),
        CyberImeKeyboardRow(_bottom(bottomRow, includeLanguage: true)),
      ],
    );
  }
}
