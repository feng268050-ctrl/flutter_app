import 'package:cyber_ime/src/session/cyber_ime_jp_input_mode.dart';

/// Local romaji → hiragana converter + tiny word candidates (utility API).
///
/// Not a full IME dictionary — enough for acceptance (`ka`, `nihongo`) and
/// replaceable later.
abstract final class CyberImeRomaji {
  /// Convert a romaji buffer to hiragana (greedy longest match).
  static String toHiragana(String romaji) {
    if (romaji.isEmpty) return '';
    final input = romaji.toLowerCase();
    final out = StringBuffer();
    var i = 0;
    while (i < input.length) {
      // Sokuon: double consonant (except n) → っ + consonant
      if (i + 1 < input.length &&
          input[i] == input[i + 1] &&
          _isConsonant(input[i]) &&
          input[i] != 'n') {
        out.write('っ');
        i++;
        continue;
      }
      // Syllabic n before consonant / end / '
      if (input[i] == 'n') {
        if (i + 1 >= input.length ||
            input[i + 1] == "'" ||
            (input[i + 1] != 'a' &&
                input[i + 1] != 'i' &&
                input[i + 1] != 'u' &&
                input[i + 1] != 'e' &&
                input[i + 1] != 'o' &&
                input[i + 1] != 'y' &&
                input[i + 1] != 'n')) {
          out.write('ん');
          i++;
          continue;
        }
      }
      var matched = false;
      for (var len = 4; len >= 1; len--) {
        if (i + len > input.length) continue;
        final chunk = input.substring(i, i + len);
        final hira = _table[chunk];
        if (hira != null) {
          out.write(hira);
          i += len;
          matched = true;
          break;
        }
      }
      if (!matched) {
        // Incomplete trailing romaji stays as latin for preedit visibility.
        out.write(input[i]);
        i++;
      }
    }
    return out.toString();
  }

  /// Candidates for [hiragana]: reading, katakana, optional dictionary words.
  static List<String> candidatesFor(String hiragana) {
    if (hiragana.isEmpty) return const [];
    final out = <String>[hiragana];
    final kata = cyberImeToKatakana(hiragana);
    if (kata != hiragana) out.add(kata);
    final words = _words[hiragana];
    if (words != null) {
      for (final w in words) {
        if (!out.contains(w)) out.add(w);
      }
    }
    return out;
  }

  static bool _isConsonant(String c) {
    const vowels = {'a', 'i', 'u', 'e', 'o'};
    return c.length == 1 && !vowels.contains(c) && RegExp(r'[a-z]').hasMatch(c);
  }

  static const Map<String, List<String>> _words = {
    'にほんご': ['日本語'],
    'にほん': ['日本'],
  };

  static const Map<String, String> _table = {
    // digraphs / longer first via greedy len loop
    'kya': 'きゃ',
    'kyu': 'きゅ',
    'kyo': 'きょ',
    'sha': 'しゃ',
    'shu': 'しゅ',
    'sho': 'しょ',
    'cha': 'ちゃ',
    'chu': 'ちゅ',
    'cho': 'ちょ',
    'nya': 'にゃ',
    'nyu': 'にゅ',
    'nyo': 'にょ',
    'hya': 'ひゃ',
    'hyu': 'ひゅ',
    'hyo': 'ひょ',
    'mya': 'みゃ',
    'myu': 'みゅ',
    'myo': 'みょ',
    'rya': 'りゃ',
    'ryu': 'りゅ',
    'ryo': 'りょ',
    'gya': 'ぎゃ',
    'gyu': 'ぎゅ',
    'gyo': 'ぎょ',
    'ja': 'じゃ',
    'ju': 'じゅ',
    'jo': 'じょ',
    'bya': 'びゃ',
    'byu': 'びゅ',
    'byo': 'びょ',
    'pya': 'ぴゃ',
    'pyu': 'ぴゅ',
    'pyo': 'ぴょ',
    'shi': 'し',
    'chi': 'ち',
    'tsu': 'つ',
    'fu': 'ふ',
    'ji': 'じ',
    'ka': 'か',
    'ki': 'き',
    'ku': 'く',
    'ke': 'け',
    'ko': 'こ',
    'sa': 'さ',
    'su': 'す',
    'se': 'せ',
    'so': 'そ',
    'ta': 'た',
    'te': 'て',
    'to': 'と',
    'na': 'な',
    'ni': 'に',
    'nu': 'ぬ',
    'ne': 'ね',
    'no': 'の',
    'ha': 'は',
    'hi': 'ひ',
    'he': 'へ',
    'ho': 'ほ',
    'ma': 'ま',
    'mi': 'み',
    'mu': 'む',
    'me': 'め',
    'mo': 'も',
    'ya': 'や',
    'yu': 'ゆ',
    'yo': 'よ',
    'ra': 'ら',
    'ri': 'り',
    'ru': 'る',
    're': 'れ',
    'ro': 'ろ',
    'wa': 'わ',
    'wo': 'を',
    'nn': 'ん',
    'ga': 'が',
    'gi': 'ぎ',
    'gu': 'ぐ',
    'ge': 'げ',
    'go': 'ご',
    'za': 'ざ',
    'zu': 'ず',
    'ze': 'ぜ',
    'zo': 'ぞ',
    'da': 'だ',
    'di': 'ぢ',
    'du': 'づ',
    'de': 'で',
    'do': 'ど',
    'ba': 'ば',
    'bi': 'び',
    'bu': 'ぶ',
    'be': 'べ',
    'bo': 'ぼ',
    'pa': 'ぱ',
    'pi': 'ぴ',
    'pu': 'ぷ',
    'pe': 'ぺ',
    'po': 'ぽ',
    'a': 'あ',
    'i': 'い',
    'u': 'う',
    'e': 'え',
    'o': 'お',
    '-': 'ー',
  };
}
