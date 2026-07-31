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
    // Second-function glyphs follow the DE phone reference by key (L→R).
    // Ö / Ä are long-press variants of O / A, not resident keys.
    const row1 = ['Q', 'W', 'E', 'R', 'T', 'Z', 'U', 'I', 'O', 'P'];
    const row1Secondaries = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    const row2Secondaries = ['@', '#', '€', '_', '&', '-', '+', '(', ')'];
    const row3 = ['Y', 'X', 'C', 'V', 'B', 'N', 'M'];
    const row3Secondaries = ['*', '"', "'", ':', ';', '!', '?'];

    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (var i = 0; i < row1.length; i++)
            _letter(
              row1[i],
              secondary: row1Secondaries[i],
              longPressOptions: switch (row1[i]) {
                'E' => const [
                    'e',
                    'é',
                    'è',
                    'ê',
                    'E',
                    'É',
                    'È',
                    'Ê',
                  ],
                'U' => const [
                    'u',
                    'ü',
                    'ú',
                    'ù',
                    'û',
                    'U',
                    'Ü',
                    'Ú',
                    'Ù',
                    'Û',
                  ],
                'O' => const [
                    'o',
                    'ö',
                    'ó',
                    'ò',
                    'ô',
                    'O',
                    'Ö',
                    'Ó',
                    'Ò',
                    'Ô',
                  ],
                _ => null,
              },
            ),
        ]),
        CyberImeKeyboardRow(
          [
            for (var i = 0; i < row2.length; i++)
              _letter(
                row2[i],
                secondary: row2Secondaries[i],
                longPressOptions: switch (row2[i]) {
                  'A' => const [
                      'a',
                      'ä',
                      'á',
                      'à',
                      'â',
                      'A',
                      'Ä',
                      'Á',
                      'À',
                      'Â',
                    ],
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

  static CyberImeLayout _azerty({
    required CyberImeBottomRowProfile bottomRow,
    required CyberImeKeyboardKind kind,
  }) {
    // Second-function glyphs follow the FR phone reference by row (L→R), not
    // by QWERTY letter pairing. Accents stay on long-press popups.
    const row1 = ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    const row1Secondaries = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row2 = ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M'];
    const row2Secondaries = ['@', '#', '€', '_', '&', '-', '+', '(', ')', '/'];
    const row3 = ['W', 'X', 'C', 'V', 'B', 'N'];
    const row3Secondaries = ['*', '"', "'", ':', ';', '!'];

    return CyberImeLayout(
      kind: kind,
      rows: [
        CyberImeKeyboardRow([
          for (var i = 0; i < row1.length; i++)
            _letter(
              row1[i],
              secondary: row1Secondaries[i],
              longPressOptions: switch (row1[i]) {
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
          for (var i = 0; i < row2.length; i++)
            _letter(row2[i], secondary: row2Secondaries[i]),
        ]),
        CyberImeKeyboardRow([
          const CyberImeKeyDef(
            id: CyberImeKeyId.shift,
            primary: '⇧',
            widthWeight: 1.5,
          ),
          for (var i = 0; i < row3.length; i++)
            _letter(
              row3[i],
              secondary: row3Secondaries[i],
              longPressOptions:
                  row3[i] == 'C' ? const ['c', 'ç', 'C', 'Ç'] : null,
            ),
          const CyberImeKeyDef(
            id: CyberImeKeyId.custom,
            primary: "'",
            secondary: '?',
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
