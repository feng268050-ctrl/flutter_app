import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter_test/flutter_test.dart';

class _BufCommit implements CyberImeCommitTarget {
  final StringBuffer buf = StringBuffer();

  @override
  String get text => buf.toString();

  @override
  void insert(String value) => buf.write(value);

  @override
  void backspace() {
    final s = buf.toString();
    if (s.isEmpty) return;
    buf
      ..clear()
      ..write(s.substring(0, s.length - 1));
  }

  @override
  void clear() => buf.clear();
}

void main() {
  tearDown(() {
    CyberImeRegionalLayoutRegistry.register(null);
  });

  test('JIS jp mode: 半/全, カナ, Shift small kana, 英数', () {
    CyberImeRegionalLayoutRegistry.register(
      CyberImeMutableRegionalLayoutProvider(CyberImeRegionalProfile.jis),
    );
    final commit = _BufCommit();
    final c = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: commit,
    );

    expect(c.jpInputMode, CyberImeJpInputMode.english);

    c.onKeyTap(
      const CyberImeKeyDef(
        id: CyberImeKeyId.hankakuZenkaku,
        primary: '半/全',
      ),
    );
    expect(c.jpInputMode, CyberImeJpInputMode.hiragana);

    final q = CyberImeLayouts.letters(profile: CyberImeRegionalProfile.jis)
        .rows[1]
        .keys
        .firstWhere((k) => k.keyCode == CyberImeKeyCode.keyQ);
    c.onKeyTap(q);
    expect(commit.text, 'た');

    c.onKeyTap(
      const CyberImeKeyDef(id: CyberImeKeyId.kanaToggle, primary: 'カナ'),
    );
    expect(c.jpInputMode, CyberImeJpInputMode.katakana);
    c.onKeyTap(q);
    expect(commit.text, 'たタ');

    c.onKeyTap(const CyberImeKeyDef(id: CyberImeKeyId.shift, primary: '⇧'));
    final z = CyberImeLayouts.letters(profile: CyberImeRegionalProfile.jis)
        .rows[3]
        .keys
        .firstWhere((k) => k.keyCode == CyberImeKeyCode.keyZ);
    c.onKeyTap(z);
    expect(commit.text, 'たタッ');

    c.onKeyTap(
      const CyberImeKeyDef(id: CyberImeKeyId.capsLock, primary: '英数'),
    );
    expect(c.jpInputMode, CyberImeJpInputMode.english);
  });
}
