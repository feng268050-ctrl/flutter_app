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

  test('JIS soft: language toggle + romaji ka / nihongo', () {
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
        id: CyberImeKeyId.languageToggle,
        primary: 'あ',
      ),
    );
    expect(c.jpInputMode, CyberImeJpInputMode.hiragana);

    void tapLetter(String upper) {
      c.onKeyTap(
        CyberImeKeyDef(
          id: CyberImeKeyId.letter,
          primary: upper,
          isLetter: true,
        ),
      );
    }

    tapLetter('K');
    tapLetter('A');
    expect(c.compositionText, 'か');
    expect(commit.text, '');
    c.onKeyTap(const CyberImeKeyDef(id: CyberImeKeyId.enter, primary: '⏎'));
    expect(commit.text, 'か');
    expect(c.hasComposition, isFalse);

    for (final ch in 'NIHONGO'.split('')) {
      tapLetter(ch);
    }
    expect(c.compositionText, 'にほんご');
    c.onKeyTap(const CyberImeKeyDef(id: CyberImeKeyId.space, primary: ' '));
    expect(c.candidatePickerOpen, isTrue);
    expect(c.candidates, contains('日本語'));
    // Cycle to 日本語 if not already selected.
    while (c.selectedCandidate != '日本語') {
      c.onKeyTap(const CyberImeKeyDef(id: CyberImeKeyId.space, primary: ' '));
    }
    c.onKeyTap(const CyberImeKeyDef(id: CyberImeKeyId.enter, primary: '⏎'));
    expect(commit.text, 'か日本語');
  });
}
