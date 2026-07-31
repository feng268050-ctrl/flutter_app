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
      // QWERTY preserves its existing digit/symbol second-function layer;
      // other regional letter pads reserve their second-function slot for
      // explicit long-press candidates.
      for (final key in layout.rows.expand((r) => r.keys)) {
        if (!key.isLetter) continue;
        if (profile == CyberImeRegionalProfile.qwerty) {
          expect(key.secondary, isNotNull, reason: '$profile ${key.primary}');
        } else {
          expect(key.secondary, isNull, reason: '$profile ${key.primary}');
        }
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

  test('QWERTZ soft swaps Y/Z and exposes umlaut long-press', () {
    final layout =
        CyberImeLayouts.letters(profile: CyberImeRegionalProfile.qwertz);
    expect(rowLabels(layout, 0), 'QWERTZUIOP'.split(''));
    expect(
      layout.rows[2].keys.where((k) => k.isLetter).map((k) => k.primary).toList(),
      'YXCVBNM'.split(''),
    );
    final a = layout.rows[1].keys.firstWhere((k) => k.primary == 'A');
    expect(a.popupOptions(), containsAll(['a', 'ä', 'A', 'Ä']));
  });

  test('AZERTY soft letter order and apostrophe', () {
    final layout =
        CyberImeLayouts.letters(profile: CyberImeRegionalProfile.azerty);
    expect(rowLabels(layout, 0), 'AZERTYUIOP'.split(''));
    expect(rowLabels(layout, 1), 'QSDFGHJKLM'.split(''));
    expect(rowLabels(layout, 2), contains("'"));
    final e = layout.rows[0].keys.firstWhere((k) => k.primary == 'E');
    expect(e.popupOptions(), containsAll(['é', 'è', 'ê', 'ë', 'É']));
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
