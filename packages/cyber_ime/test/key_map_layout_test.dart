import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CyberImeRegionalLayoutRegistry.register(null);
  });

  test('DE KeyMap swaps Y/Z vs US', () {
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.ansi,
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

  test('Default is phone pad; ANSI is typewriter with Ctrl/Alt/Space', () {
    final phone = CyberImeLayouts.letters(
      profile: CyberImeRegionalProfile.defaultSoft,
    );
    expect(phone.rows.length, 4);
    expect(rowLabels(phone, 3), isNot(contains('AltGr')));

    final ansi = CyberImeLayouts.letters(
      profile: CyberImeRegionalProfile.ansi,
    );
    expect(ansi.rows.length, 5);
    final bottom = rowLabels(ansi, 4);
    expect(bottom, contains('Ctrl'));
    expect(bottom, contains('Alt'));
    expect(bottom, isNot(contains('AltGr')));
    expect(bottom, isNot(contains('123')));
    // Number row has Shift-layer secondaries (e.g. 1 → !).
    final digit1 = ansi.rows[0].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.digit1,
    );
    expect(digit1.primary, '1');
    expect(digit1.secondary, '!');
    expect(digit1.popupOptions(), ['1', '!']);
    // Letters expose normal/shift popup for long-press slide.
    final keyQ = ansi.rows[1].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.keyQ,
    );
    expect(keyQ.popupOptions(), ['q', 'Q']);
    expect(
      ansi.rows.expand((r) => r.keys).any((k) =>
          k.secondary != null &&
          k.secondary!.isNotEmpty &&
          k.keyCode != null),
      isTrue,
    );
  });

  test('ANSI KeyMap digit Shift layer matches US symbols', () {
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
      CyberImeKeyCode.minus: '_',
      CyberImeKeyCode.equal: '+',
      CyberImeKeyCode.bracketLeft: '{',
      CyberImeKeyCode.bracketRight: '}',
      CyberImeKeyCode.backslash: '|',
      CyberImeKeyCode.semicolon: ':',
      CyberImeKeyCode.quote: '"',
      CyberImeKeyCode.comma: '<',
      CyberImeKeyCode.period: '>',
      CyberImeKeyCode.slash: '?',
      CyberImeKeyCode.grave: '~',
    };
    for (final e in cases.entries) {
      expect(
        CyberImeKeyMaps.resolve(
          CyberImeRegionalProfile.ansi,
          e.key,
          shiftOn: true,
        ),
        e.value,
        reason: '${e.key}',
      );
    }
  });

  test('QWERTZ ISO typewriter geometry and Shift layer', () {
    final layout = CyberImeLayouts.letters(
      profile: CyberImeRegionalProfile.qwertz,
    );
    expect(layout.rows.length, 5);
    final letters = rowLabels(layout, 1).where((l) => l.length == 1).toList();
    expect(letters.take(10).toList(),
        ['Q', 'W', 'E', 'R', 'T', 'Z', 'U', 'I', 'O', 'P']);
    // ü / + on letter row; one ISO L-Enter (rowSpan 2); ö ä # on home (no 2nd Enter).
    expect(rowLabels(layout, 1), containsAll(['Ü', '+']));
    expect(layout.rows[1].keys.last.id, CyberImeKeyId.enter);
    expect(layout.rows[1].keys.last.rowSpan, 2);
    expect(rowLabels(layout, 2), containsAll(['Ö', 'Ä', '#']));
    expect(
      layout.rows[2].keys.any((k) => k.id == CyberImeKeyId.enter),
      isFalse,
    );
    // Longer Caps shifts home row right → inverted-L Enter notch.
    expect(layout.rows[2].keys.first.id, CyberImeKeyId.capsLock);
    expect(layout.rows[2].keys.first.widthWeight, 1.8);
    expect(
      layout.rows[3].keys[1].keyCode,
      CyberImeKeyCode.intlBackslash,
    );
    final bottom = rowLabels(layout, 4);
    expect(bottom, containsAll(['Ctrl', 'Alt', 'AltGr']));
    expect(bottom, isNot(contains('123')));

    final digit2 = layout.rows[0].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.digit2,
    );
    expect(digit2.primary, '2');
    expect(digit2.secondary, '"');
    expect(digit2.popupOptions(), ['2', '"']);

    final keyQ = layout.rows[1].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.keyQ,
    );
    expect(keyQ.popupOptions(), ['Q', '@', 'q']);

    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.qwertz,
        CyberImeKeyCode.minus,
        shiftOn: false,
      ),
      'ß',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.qwertz,
        CyberImeKeyCode.digit7,
        shiftOn: true,
      ),
      '/',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.qwertz,
        CyberImeKeyCode.digit7,
        shiftOn: false,
        altGrOn: true,
      ),
      '{',
    );
  });

  test('AZERTY typewriter geometry', () {
    final layout = CyberImeLayouts.letters(
      profile: CyberImeRegionalProfile.azerty,
    );
    expect(rowLabels(layout, 1).sublist(1, 11),
        ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']);
    expect(rowLabels(layout, 0).first, '²');
    expect(rowLabels(layout, 4), contains('AltGr'));
    expect(rowLabels(layout, 4), contains('Ctrl'));

    // ù (right of m): Shift % must show as secondary (not dropped as "letter").
    final ugrave = layout.rows[2].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.quote,
    );
    expect(ugrave.primary, 'ù');
    expect(ugrave.secondary, '%');
    expect(ugrave.isLetter, isFalse);

    // é digit: Shift 2 as secondary (accented base is not a case-pair letter).
    final digit2 = layout.rows[0].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.digit2,
    );
    expect(digit2.primary, 'é');
    expect(digit2.secondary, '2');

    final keyE = layout.rows[1].keys.firstWhere(
      (k) => k.keyCode == CyberImeKeyCode.keyE,
    );
    expect(keyE.isLetter, isTrue);
    expect(keyE.secondary, '€');
  });

  test('JIS typewriter has ¥ and JP keys, no F-row/numpad', () {
    final layout = CyberImeLayouts.letters(
      profile: CyberImeRegionalProfile.jis,
    );
    final all = layout.rows.expand((r) => r.keys).map((k) => k.primary);
    expect(all, contains('¥'));
    expect(all, contains('半/全'));
    expect(all, contains('英数'));
    expect(all, contains('無変換'));
    expect(all, contains('変換'));
    expect(all, contains('カナ'));
    expect(all, isNot(contains('AltGr')));
    expect(all.any((l) => RegExp(r'^F\d+$').hasMatch(l)), isFalse);

    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.jis,
        CyberImeKeyCode.keyQ,
        shiftOn: false,
        jpMode: CyberImeJpInputMode.hiragana,
      ),
      'た',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.jis,
        CyberImeKeyCode.keyZ,
        shiftOn: true,
        jpMode: CyberImeJpInputMode.hiragana,
      ),
      'っ',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.jis,
        CyberImeKeyCode.keyQ,
        shiftOn: false,
        jpMode: CyberImeJpInputMode.katakana,
      ),
      'タ',
    );
    expect(
      CyberImeKeyMaps.resolve(
        CyberImeRegionalProfile.jis,
        CyberImeKeyCode.yen,
        shiftOn: false,
      ),
      '¥',
    );
  });
}
