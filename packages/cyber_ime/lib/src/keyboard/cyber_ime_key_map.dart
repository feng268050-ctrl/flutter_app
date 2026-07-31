import 'package:cyber_ime/src/keyboard/cyber_ime_key_code.dart';
import 'package:cyber_ime/src/session/cyber_ime_jp_input_mode.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';

/// One key’s character levels (base / Shift / optional AltGr / optional kana).
///
/// Soft CyberIME resolves commit text from these tables. Physical typing uses
/// XKB with the matching layout id; tables are aligned to xkeyboard-config for
/// the typewriter block (not F-keys / NumPad).
final class CyberImeCharLevel {
  const CyberImeCharLevel({
    required this.base,
    this.shift,
    this.altGr,
    this.kana,
    this.kanaShift,
  });

  final String base;
  final String? shift;
  final String? altGr;

  /// Hiragana (unshifted) for JIS kana modes.
  final String? kana;

  /// Hiragana Shift layer (small kana / を / ゜ / …).
  final String? kanaShift;

  String resolve({
    required bool shiftOn,
    bool altGrOn = false,
    CyberImeJpInputMode jpMode = CyberImeJpInputMode.english,
  }) {
    if (jpMode == CyberImeJpInputMode.hiragana ||
        jpMode == CyberImeJpInputMode.katakana) {
      final raw = shiftOn
          ? (kanaShift ?? kana)
          : kana;
      if (raw != null && raw.isNotEmpty) {
        return jpMode == CyberImeJpInputMode.katakana
            ? cyberImeToKatakana(raw)
            : raw;
      }
      // No kana slot — fall through to Latin (e.g. rare keys).
    }
    if (altGrOn && altGr != null && altGr!.isNotEmpty) {
      return altGr!;
    }
    if (shiftOn && shift != null && shift!.isNotEmpty) {
      return shift!;
    }
    return base;
  }
}

/// Per-profile KeyCode → character maps for the typewriter block.
abstract final class CyberImeKeyMaps {
  static Map<CyberImeKeyCode, CyberImeCharLevel> forProfile(
    CyberImeRegionalProfile profile,
  ) {
    return switch (profile) {
      CyberImeRegionalProfile.qwerty => ansiUs,
      CyberImeRegionalProfile.qwertz => isoDe,
      CyberImeRegionalProfile.azerty => isoFr,
    };
  }

  static CyberImeCharLevel level(
    CyberImeRegionalProfile profile,
    CyberImeKeyCode code,
  ) {
    final map = forProfile(profile);
    return map[code] ?? const CyberImeCharLevel(base: '');
  }

  static String resolve(
    CyberImeRegionalProfile profile,
    CyberImeKeyCode code, {
    required bool shiftOn,
    bool altGrOn = false,
    CyberImeJpInputMode jpMode = CyberImeJpInputMode.english,
  }) {
    return level(profile, code).resolve(
      shiftOn: shiftOn,
      altGrOn: altGrOn,
      jpMode: jpMode,
    );
  }

  /// US ANSI QWERTY (identity = KeyCode names).
  static const Map<CyberImeKeyCode, CyberImeCharLevel> ansiUs = {
    CyberImeKeyCode.grave: CyberImeCharLevel(base: '`', shift: '~'),
    CyberImeKeyCode.digit1: CyberImeCharLevel(base: '1', shift: '!'),
    CyberImeKeyCode.digit2: CyberImeCharLevel(base: '2', shift: '@'),
    CyberImeKeyCode.digit3: CyberImeCharLevel(base: '3', shift: '#'),
    CyberImeKeyCode.digit4: CyberImeCharLevel(base: '4', shift: r'$'),
    CyberImeKeyCode.digit5: CyberImeCharLevel(base: '5', shift: '%'),
    CyberImeKeyCode.digit6: CyberImeCharLevel(base: '6', shift: '^'),
    CyberImeKeyCode.digit7: CyberImeCharLevel(base: '7', shift: '&'),
    CyberImeKeyCode.digit8: CyberImeCharLevel(base: '8', shift: '*'),
    CyberImeKeyCode.digit9: CyberImeCharLevel(base: '9', shift: '('),
    CyberImeKeyCode.digit0: CyberImeCharLevel(base: '0', shift: ')'),
    CyberImeKeyCode.minus: CyberImeCharLevel(base: '-', shift: '_'),
    CyberImeKeyCode.equal: CyberImeCharLevel(base: '=', shift: '+'),
    CyberImeKeyCode.keyQ: CyberImeCharLevel(base: 'q', shift: 'Q'),
    CyberImeKeyCode.keyW: CyberImeCharLevel(base: 'w', shift: 'W'),
    CyberImeKeyCode.keyE: CyberImeCharLevel(base: 'e', shift: 'E'),
    CyberImeKeyCode.keyR: CyberImeCharLevel(base: 'r', shift: 'R'),
    CyberImeKeyCode.keyT: CyberImeCharLevel(base: 't', shift: 'T'),
    CyberImeKeyCode.keyY: CyberImeCharLevel(base: 'y', shift: 'Y'),
    CyberImeKeyCode.keyU: CyberImeCharLevel(base: 'u', shift: 'U'),
    CyberImeKeyCode.keyI: CyberImeCharLevel(base: 'i', shift: 'I'),
    CyberImeKeyCode.keyO: CyberImeCharLevel(base: 'o', shift: 'O'),
    CyberImeKeyCode.keyP: CyberImeCharLevel(base: 'p', shift: 'P'),
    CyberImeKeyCode.keyA: CyberImeCharLevel(base: 'a', shift: 'A'),
    CyberImeKeyCode.keyS: CyberImeCharLevel(base: 's', shift: 'S'),
    CyberImeKeyCode.keyD: CyberImeCharLevel(base: 'd', shift: 'D'),
    CyberImeKeyCode.keyF: CyberImeCharLevel(base: 'f', shift: 'F'),
    CyberImeKeyCode.keyG: CyberImeCharLevel(base: 'g', shift: 'G'),
    CyberImeKeyCode.keyH: CyberImeCharLevel(base: 'h', shift: 'H'),
    CyberImeKeyCode.keyJ: CyberImeCharLevel(base: 'j', shift: 'J'),
    CyberImeKeyCode.keyK: CyberImeCharLevel(base: 'k', shift: 'K'),
    CyberImeKeyCode.keyL: CyberImeCharLevel(base: 'l', shift: 'L'),
    CyberImeKeyCode.keyZ: CyberImeCharLevel(base: 'z', shift: 'Z'),
    CyberImeKeyCode.keyX: CyberImeCharLevel(base: 'x', shift: 'X'),
    CyberImeKeyCode.keyC: CyberImeCharLevel(base: 'c', shift: 'C'),
    CyberImeKeyCode.keyV: CyberImeCharLevel(base: 'v', shift: 'V'),
    CyberImeKeyCode.keyB: CyberImeCharLevel(base: 'b', shift: 'B'),
    CyberImeKeyCode.keyN: CyberImeCharLevel(base: 'n', shift: 'N'),
    CyberImeKeyCode.keyM: CyberImeCharLevel(base: 'm', shift: 'M'),
    CyberImeKeyCode.bracketLeft: CyberImeCharLevel(base: '[', shift: '{'),
    CyberImeKeyCode.bracketRight: CyberImeCharLevel(base: ']', shift: '}'),
    CyberImeKeyCode.backslash: CyberImeCharLevel(base: r'\', shift: '|'),
    CyberImeKeyCode.semicolon: CyberImeCharLevel(base: ';', shift: ':'),
    CyberImeKeyCode.quote: CyberImeCharLevel(base: "'", shift: '"'),
    CyberImeKeyCode.comma: CyberImeCharLevel(base: ',', shift: '<'),
    CyberImeKeyCode.period: CyberImeCharLevel(base: '.', shift: '>'),
    CyberImeKeyCode.slash: CyberImeCharLevel(base: '/', shift: '?'),
    CyberImeKeyCode.intlBackslash: CyberImeCharLevel(base: r'\', shift: '|'),
    CyberImeKeyCode.yen: CyberImeCharLevel(base: r'\', shift: '|'),
  };

  /// German QWERTZ ISO (DE).
  static const Map<CyberImeKeyCode, CyberImeCharLevel> isoDe = {
    CyberImeKeyCode.grave: CyberImeCharLevel(base: '^', shift: '°'),
    CyberImeKeyCode.digit1: CyberImeCharLevel(base: '1', shift: '!'),
    CyberImeKeyCode.digit2: CyberImeCharLevel(base: '2', shift: '"', altGr: '²'),
    CyberImeKeyCode.digit3: CyberImeCharLevel(base: '3', shift: '§', altGr: '³'),
    CyberImeKeyCode.digit4: CyberImeCharLevel(base: '4', shift: r'$'),
    CyberImeKeyCode.digit5: CyberImeCharLevel(base: '5', shift: '%'),
    CyberImeKeyCode.digit6: CyberImeCharLevel(base: '6', shift: '&'),
    CyberImeKeyCode.digit7: CyberImeCharLevel(base: '7', shift: '/', altGr: '{'),
    CyberImeKeyCode.digit8: CyberImeCharLevel(base: '8', shift: '(', altGr: '['),
    CyberImeKeyCode.digit9: CyberImeCharLevel(base: '9', shift: ')', altGr: ']'),
    CyberImeKeyCode.digit0: CyberImeCharLevel(base: '0', shift: '=', altGr: '}'),
    CyberImeKeyCode.minus: CyberImeCharLevel(base: 'ß', shift: '?', altGr: r'\'),
    CyberImeKeyCode.equal: CyberImeCharLevel(base: '´', shift: '`'),
    CyberImeKeyCode.keyQ: CyberImeCharLevel(base: 'q', shift: 'Q', altGr: '@'),
    CyberImeKeyCode.keyW: CyberImeCharLevel(base: 'w', shift: 'W'),
    CyberImeKeyCode.keyE: CyberImeCharLevel(base: 'e', shift: 'E', altGr: '€'),
    CyberImeKeyCode.keyR: CyberImeCharLevel(base: 'r', shift: 'R'),
    CyberImeKeyCode.keyT: CyberImeCharLevel(base: 't', shift: 'T'),
    CyberImeKeyCode.keyY: CyberImeCharLevel(base: 'z', shift: 'Z'),
    CyberImeKeyCode.keyU: CyberImeCharLevel(base: 'u', shift: 'U'),
    CyberImeKeyCode.keyI: CyberImeCharLevel(base: 'i', shift: 'I'),
    CyberImeKeyCode.keyO: CyberImeCharLevel(base: 'o', shift: 'O'),
    CyberImeKeyCode.keyP: CyberImeCharLevel(base: 'p', shift: 'P'),
    CyberImeKeyCode.keyA: CyberImeCharLevel(base: 'a', shift: 'A'),
    CyberImeKeyCode.keyS: CyberImeCharLevel(base: 's', shift: 'S'),
    CyberImeKeyCode.keyD: CyberImeCharLevel(base: 'd', shift: 'D'),
    CyberImeKeyCode.keyF: CyberImeCharLevel(base: 'f', shift: 'F'),
    CyberImeKeyCode.keyG: CyberImeCharLevel(base: 'g', shift: 'G'),
    CyberImeKeyCode.keyH: CyberImeCharLevel(base: 'h', shift: 'H'),
    CyberImeKeyCode.keyJ: CyberImeCharLevel(base: 'j', shift: 'J'),
    CyberImeKeyCode.keyK: CyberImeCharLevel(base: 'k', shift: 'K'),
    CyberImeKeyCode.keyL: CyberImeCharLevel(base: 'l', shift: 'L'),
    CyberImeKeyCode.keyZ: CyberImeCharLevel(base: 'y', shift: 'Y'),
    CyberImeKeyCode.keyX: CyberImeCharLevel(base: 'x', shift: 'X'),
    CyberImeKeyCode.keyC: CyberImeCharLevel(base: 'c', shift: 'C'),
    CyberImeKeyCode.keyV: CyberImeCharLevel(base: 'v', shift: 'V'),
    CyberImeKeyCode.keyB: CyberImeCharLevel(base: 'b', shift: 'B'),
    CyberImeKeyCode.keyN: CyberImeCharLevel(base: 'n', shift: 'N'),
    CyberImeKeyCode.keyM: CyberImeCharLevel(base: 'm', shift: 'M', altGr: 'µ'),
    CyberImeKeyCode.bracketLeft: CyberImeCharLevel(base: 'ü', shift: 'Ü'),
    CyberImeKeyCode.bracketRight:
        CyberImeCharLevel(base: '+', shift: '*', altGr: '~'),
    CyberImeKeyCode.backslash: CyberImeCharLevel(base: '#', shift: "'"),
    CyberImeKeyCode.semicolon: CyberImeCharLevel(base: 'ö', shift: 'Ö'),
    CyberImeKeyCode.quote: CyberImeCharLevel(base: 'ä', shift: 'Ä'),
    CyberImeKeyCode.comma: CyberImeCharLevel(base: ',', shift: ';'),
    CyberImeKeyCode.period: CyberImeCharLevel(base: '.', shift: ':'),
    CyberImeKeyCode.slash: CyberImeCharLevel(base: '-', shift: '_'),
    CyberImeKeyCode.intlBackslash:
        CyberImeCharLevel(base: '<', shift: '>', altGr: '|'),
    CyberImeKeyCode.yen: CyberImeCharLevel(base: '#', shift: "'"),
  };

  /// French AZERTY ISO.
  static const Map<CyberImeKeyCode, CyberImeCharLevel> isoFr = {
    CyberImeKeyCode.grave: CyberImeCharLevel(base: '²'),
    CyberImeKeyCode.digit1: CyberImeCharLevel(base: '&', shift: '1'),
    CyberImeKeyCode.digit2: CyberImeCharLevel(base: 'é', shift: '2', altGr: '~'),
    CyberImeKeyCode.digit3: CyberImeCharLevel(base: '"', shift: '3', altGr: '#'),
    CyberImeKeyCode.digit4: CyberImeCharLevel(base: "'", shift: '4', altGr: '{'),
    CyberImeKeyCode.digit5: CyberImeCharLevel(base: '(', shift: '5', altGr: '['),
    CyberImeKeyCode.digit6: CyberImeCharLevel(base: '-', shift: '6', altGr: '|'),
    CyberImeKeyCode.digit7: CyberImeCharLevel(base: 'è', shift: '7', altGr: '`'),
    CyberImeKeyCode.digit8: CyberImeCharLevel(base: '_', shift: '8', altGr: r'\'),
    CyberImeKeyCode.digit9: CyberImeCharLevel(base: 'ç', shift: '9', altGr: '^'),
    CyberImeKeyCode.digit0: CyberImeCharLevel(base: 'à', shift: '0', altGr: '@'),
    CyberImeKeyCode.minus: CyberImeCharLevel(base: ')', shift: '°', altGr: ']'),
    CyberImeKeyCode.equal: CyberImeCharLevel(base: '=', shift: '+', altGr: '}'),
    CyberImeKeyCode.keyQ: CyberImeCharLevel(base: 'a', shift: 'A'),
    CyberImeKeyCode.keyW: CyberImeCharLevel(base: 'z', shift: 'Z'),
    CyberImeKeyCode.keyE: CyberImeCharLevel(base: 'e', shift: 'E', altGr: '€'),
    CyberImeKeyCode.keyR: CyberImeCharLevel(base: 'r', shift: 'R'),
    CyberImeKeyCode.keyT: CyberImeCharLevel(base: 't', shift: 'T'),
    CyberImeKeyCode.keyY: CyberImeCharLevel(base: 'y', shift: 'Y'),
    CyberImeKeyCode.keyU: CyberImeCharLevel(base: 'u', shift: 'U'),
    CyberImeKeyCode.keyI: CyberImeCharLevel(base: 'i', shift: 'I'),
    CyberImeKeyCode.keyO: CyberImeCharLevel(base: 'o', shift: 'O'),
    CyberImeKeyCode.keyP: CyberImeCharLevel(base: 'p', shift: 'P'),
    CyberImeKeyCode.keyA: CyberImeCharLevel(base: 'q', shift: 'Q'),
    CyberImeKeyCode.keyS: CyberImeCharLevel(base: 's', shift: 'S'),
    CyberImeKeyCode.keyD: CyberImeCharLevel(base: 'd', shift: 'D'),
    CyberImeKeyCode.keyF: CyberImeCharLevel(base: 'f', shift: 'F'),
    CyberImeKeyCode.keyG: CyberImeCharLevel(base: 'g', shift: 'G'),
    CyberImeKeyCode.keyH: CyberImeCharLevel(base: 'h', shift: 'H'),
    CyberImeKeyCode.keyJ: CyberImeCharLevel(base: 'j', shift: 'J'),
    CyberImeKeyCode.keyK: CyberImeCharLevel(base: 'k', shift: 'K'),
    CyberImeKeyCode.keyL: CyberImeCharLevel(base: 'l', shift: 'L'),
    CyberImeKeyCode.keyZ: CyberImeCharLevel(base: 'w', shift: 'W'),
    CyberImeKeyCode.keyX: CyberImeCharLevel(base: 'x', shift: 'X'),
    CyberImeKeyCode.keyC: CyberImeCharLevel(base: 'c', shift: 'C'),
    CyberImeKeyCode.keyV: CyberImeCharLevel(base: 'v', shift: 'V'),
    CyberImeKeyCode.keyB: CyberImeCharLevel(base: 'b', shift: 'B'),
    CyberImeKeyCode.keyN: CyberImeCharLevel(base: 'n', shift: 'N'),
    CyberImeKeyCode.keyM: CyberImeCharLevel(base: ',', shift: '?'),
    CyberImeKeyCode.bracketLeft: CyberImeCharLevel(base: '^', shift: '¨'),
    CyberImeKeyCode.bracketRight:
        CyberImeCharLevel(base: r'$', shift: '£', altGr: '¤'),
    CyberImeKeyCode.backslash: CyberImeCharLevel(base: '*', shift: 'µ'),
    CyberImeKeyCode.semicolon: CyberImeCharLevel(base: 'm', shift: 'M'),
    CyberImeKeyCode.quote: CyberImeCharLevel(base: 'ù', shift: '%'),
    CyberImeKeyCode.comma: CyberImeCharLevel(base: ';', shift: '.'),
    CyberImeKeyCode.period: CyberImeCharLevel(base: ':', shift: '/'),
    CyberImeKeyCode.slash: CyberImeCharLevel(base: '!', shift: '§'),
    CyberImeKeyCode.intlBackslash: CyberImeCharLevel(base: '<', shift: '>'),
    CyberImeKeyCode.yen: CyberImeCharLevel(base: '*', shift: 'µ'),
  };
}
