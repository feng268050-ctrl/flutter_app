import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CyberImeRegionalLayoutRegistry.register(null);
  });

  test('legacy profile ids parse to qwerty', () {
    expect(CyberImeRegionalProfile.parse('default'), CyberImeRegionalProfile.qwerty);
    expect(CyberImeRegionalProfile.parse('ansi'), CyberImeRegionalProfile.qwerty);
    expect(CyberImeRegionalProfile.parse(''), CyberImeRegionalProfile.qwerty);
    expect(CyberImeRegionalProfile.parse('jis'), CyberImeRegionalProfile.qwerty);
    expect(CyberImeRegionalProfile.parse('jp'), CyberImeRegionalProfile.qwerty);
    expect(CyberImeRegionalProfile.values.map((e) => e.segmentLabel).toList(),
        ['QWERTY', 'QWERTZ', 'AZERTY']);
  });

  test('DE KeyMap swaps Y/Z vs US', () {
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.qwerty,
        CyberImeKeyCode.keyY,
        shiftOn: false,
      ),
      'y',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.qwertz,
        CyberImeKeyCode.keyY,
        shiftOn: false,
      ),
      'z',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.qwertz,
        CyberImeKeyCode.keyZ,
        shiftOn: false,
      ),
      'y',
    );
  });

  test('FR KeyMap AZERTY on physical Q/W/A/Z', () {
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.azerty,
        CyberImeKeyCode.keyQ,
        shiftOn: true,
      ),
      'A',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.azerty,
        CyberImeKeyCode.keyW,
        shiftOn: true,
      ),
      'Z',
    );
  });

  List<String> rowLabels(CyberImeLayout layout, int row) =>
      layout.rows[row].keys.map((k) => k.primary).toList();

  test('all soft profiles are phone pads without typewriter chrome', () {
    for (final profile in CyberImeRegionalProfile.values) {
      final layout = CyberImeLayouts.letters(profile: profile);
      expect(layout.rows.length, 4, reason: '$profile');
      final all = layout.rows.expand((r) => r.keys).map((k) => k.primary);
      expect(all, isNot(contains('Ctrl')), reason: '$profile');
      expect(all, isNot(contains('Alt')), reason: '$profile');
      expect(all, isNot(contains('AltGr')), reason: '$profile');
      expect(all, isNot(contains('Tab')), reason: '$profile');
      expect(rowLabels(layout, 0).any((l) => RegExp(r'^\d$').hasMatch(l)),
          isFalse,
          reason: '$profile');
      // Soft letter pads expose digit/symbol second-function faces; accent /
      // umlaut variants stay on long-press popups.
      for (final key in layout.rows.expand((r) => r.keys)) {
        if (!key.isLetter) continue;
        expect(key.secondary, isNotNull, reason: '$profile ${key.primary}');
        if (key.longPressOptions != null) {
          expect(
            key.longPressOptions!.any((o) => RegExp(r'^\d$').hasMatch(o)),
            isFalse,
          );
        }
      }
    }
  });

  test('QWERTY soft letter order', () {
    final layout =
        CyberImeLayouts.letters(profile: CyberImeRegionalProfile.qwerty);
    expect(rowLabels(layout, 0), 'QWERTYUIOP'.split(''));
    expect(rowLabels(layout, 1), 'ASDFGHJKL'.split(''));
    expect(
      layout.rows[2].keys.map((k) => k.id).toList(),
      [
        CyberImeKeyId.shift,
        ...List.filled(7, CyberImeKeyId.letter),
        CyberImeKeyId.backspace,
      ],
    );
    expect(rowLabels(layout, 3).first, '123');
    expect(rowLabels(layout, 3), isNot(contains('.')));
    expect(
      layout.rows[0].keys.map((k) => k.secondary).toList(),
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    );
    expect(
      layout.rows[1].keys.map((k) => k.secondary).toList(),
      ['~', '!', '@', '#', '%', '"', "'", '*', '?'],
    );
    expect(layout.rows[0].keys.first.popupOptions(), ['q', '1', 'Q']);
  });

  test('QWERTZ soft letter order, secondaries, and umlaut long-press', () {
    final layout =
        CyberImeLayouts.letters(profile: CyberImeRegionalProfile.qwertz);
    expect(rowLabels(layout, 0), 'QWERTZUIOP'.split(''));
    expect(rowLabels(layout, 1), 'ASDFGHJKL'.split(''));
    expect(
      layout.rows[2].keys.where((k) => k.isLetter).map((k) => k.primary).toList(),
      'YXCVBNM'.split(''),
    );
    expect(
      layout.rows[0].keys.map((k) => k.secondary).toList(),
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    );
    expect(
      layout.rows[1].keys.map((k) => k.secondary).toList(),
      ['@', '#', '€', '_', '&', '-', '+', '(', ')'],
    );
    expect(
      layout.rows[2].keys.where((k) => k.isLetter).map((k) => k.secondary).toList(),
      ['*', '"', "'", ':', ';', '!', '?'],
    );
    final a = layout.rows[1].keys.firstWhere((k) => k.primary == 'A');
    expect(a.popupOptions(), containsAll(['a', 'ä', 'á', 'à', 'â', 'A', 'Ä']));
    final o = layout.rows[0].keys.firstWhere((k) => k.primary == 'O');
    expect(o.popupOptions(), containsAll(['ö', 'ó', 'ò', 'ô', 'Ö']));
    final u = layout.rows[0].keys.firstWhere((k) => k.primary == 'U');
    expect(u.popupOptions(), containsAll(['ü', 'ú', 'ù', 'û', 'Ü']));
    final s = layout.rows[1].keys.firstWhere((k) => k.primary == 'S');
    expect(s.popupOptions(), containsAll(['ß', 'ẞ']));
    final e = layout.rows[0].keys.firstWhere((k) => k.primary == 'E');
    expect(e.popupOptions(), containsAll(['é', 'è', 'ê', 'É']));
  });

  test('AZERTY soft letter order and apostrophe', () {
    final layout =
        CyberImeLayouts.letters(profile: CyberImeRegionalProfile.azerty);
    expect(rowLabels(layout, 0), 'AZERTYUIOP'.split(''));
    expect(rowLabels(layout, 1), 'QSDFGHJKLM'.split(''));
    expect(rowLabels(layout, 2), contains("'"));
    final e = layout.rows[0].keys.firstWhere((k) => k.primary == 'E');
    expect(e.popupOptions(), containsAll(['é', 'è', 'ê', 'ë', 'É']));
    expect(
      layout.rows[0].keys.map((k) => k.secondary).toList(),
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    );
    expect(
      layout.rows[1].keys.map((k) => k.secondary).toList(),
      ['@', '#', '€', '_', '&', '-', '+', '(', ')', '/'],
    );
    expect(
      layout.rows[2].keys
          .where((k) => k.isLetter || k.primary == "'")
          .map((k) => k.secondary)
          .toList(),
      ['*', '"', "'", ':', ';', '!', '?'],
    );
  });

  test('shared symbols pages are identical across regional profiles', () {
    List<String> labels(CyberImeLayout layout, int row) =>
        layout.rows[row].keys.map((k) => k.primary).toList();

    for (final profile in CyberImeRegionalProfile.values) {
      final primary = CyberImeLayouts.symbolsPrimary(profile: profile);
      expect(labels(primary, 0), '1234567890'.split(''), reason: '$profile');
      expect(
        labels(primary, 1),
        ['-', '/', ':', ';', '(', ')', r'$', '&', '@', '"'],
        reason: '$profile',
      );
      expect(primary.rows[2].keys.first.id, CyberImeKeyId.symbolsMore);
      expect(primary.rows[2].keys.first.primary, '#+=');
      expect(
        primary.rows[2].keys.skip(1).take(5).map((k) => k.primary).toList(),
        [',', '.', '?', '!', "'"],
      );
      expect(
        primary.rows[2].keys.firstWhere((k) => k.primary == "'").secondary,
        '`',
      );

      final extended = CyberImeLayouts.symbolsExtended(profile: profile);
      expect(
        labels(extended, 0),
        ['[', ']', '{', '}', '#', '%', '^', '*', '+', '='],
        reason: '$profile',
      );
      expect(
        labels(extended, 1),
        ['_', r'\', '|', '~', '<', '>', '€', '£', '¥', '•'],
        reason: '$profile',
      );
      expect(extended.rows[2].keys.first.primary, '123');
      expect(
        extended.rows[2].keys.firstWhere((k) => k.primary == "'").secondary,
        '`',
      );
    }
  });

  test('romaji converts ka and nihongo', () {
    expect(CyberImeRomaji.toHiragana('ka'), 'か');
    expect(CyberImeRomaji.toHiragana('nihongo'), 'にほんご');
    expect(
      CyberImeRomaji.candidatesFor('にほんご'),
      containsAll(['にほんご', 'ニホンゴ', '日本語']),
    );
  });

  test('QWERTY KeyMap digit Shift layer matches US symbols', () {
    const cases = <CyberImeKeyCode, String>{
      CyberImeKeyCode.digit1: '!',
      CyberImeKeyCode.digit2: '@',
      CyberImeKeyCode.digit3: '#',
      CyberImeKeyCode.digit4: r'$',
      CyberImeKeyCode.digit5: '%',
      CyberImeKeyCode.digit6: '^',
      CyberImeKeyCode.digit7: '&',
      CyberImeKeyCode.digit8: '*',
      CyberImeKeyCode.digit9: '(',
      CyberImeKeyCode.digit0: ')',
    };
    for (final e in cases.entries) {
      expect(
        CyberImeKeyMaps.resolve(
          CyberImeRegionalProfile.qwerty,
          e.key,
          shiftOn: true,
        ),
        e.value,
        reason: '${e.key}',
      );
    }
  });
}
