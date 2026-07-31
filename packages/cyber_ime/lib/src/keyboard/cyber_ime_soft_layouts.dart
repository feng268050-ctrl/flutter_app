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
    };
  }

  static CyberImeKeyDef _letter(
    String ch, {
    String? secondary,
    List<String>? longPressOptions,
  }) {
    return CyberImeKeyDef(
      id: CyberImeKeyId.letter,
      primary: ch.toUpperCase(),
      secondary: secondary,
      isLetter: true,
      longPressOptions: longPressOptions,
    );
  }

  static List<CyberImeKeyDef> _bottom(CyberImeBottomRowProfile bottomRow) {
    return cyberImeSoftBottomRowKeys(bottomRow);
  }

  static CyberImeLayout _qwerty({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    const row1 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    const row1Secondaries = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    const row2Secondaries = ['~', '!', '@', '#', '%', '"', "'", '*', '?'];
    const row3 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M'];
    const row3Secondaries = ['(', ')', '-', '_', ':', ';', '/'];

    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (var i = 0; i < row1.length; i++)
            _letter(row1[i], secondary: row1Secondaries[i]),
        ]),
        CyberImeKeyboardRow(
          [
            for (var i = 0; i < row2.length; i++)
              _letter(row2[i], secondary: row2Secondaries[i]),
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
          for (var i = 0; i < row3.length; i++)
            _letter(row3[i], secondary: row3Secondaries[i]),
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

}
