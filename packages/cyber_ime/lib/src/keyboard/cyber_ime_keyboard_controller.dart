import 'package:cyber_ime/src/field/cyber_ime_field_profile.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_profile_registry.dart';
import 'package:cyber_ime/src/field/cyber_ime_field_type.dart';
import 'package:cyber_ime/src/field/cyber_ime_numeric_policy.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_map.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layout.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_layouts.dart';
import 'package:cyber_ime/src/session/cyber_ime_action.dart';
import 'package:cyber_ime/src/session/cyber_ime_commit.dart';
import 'package:cyber_ime/src/session/cyber_ime_jp_input_mode.dart';
import 'package:cyber_ime/src/session/cyber_ime_language.dart';
import 'package:cyber_ime/src/session/cyber_ime_regional_layout.dart';
import 'package:cyber_ime/src/session/cyber_ime_romaji.dart';
import 'package:flutter/foundation.dart';

/// Drives layout state and commit path for one focused field.
class CyberImeKeyboardController extends ChangeNotifier {
  CyberImeKeyboardController({
    required this.fieldType,
    required this.commit,
    this.action = CyberImeAction.done,
    this.onAction,
    this.onPasswordReveal,
    CyberImeNumericPolicy? numericPolicyOverride,
  }) : profile = CyberImeFieldProfileRegistry.profile(
          fieldType,
          numericPolicyOverride: numericPolicyOverride,
        ) {
    _kind = _initialLetterKind();
    _shiftOn = false;
  }

  final CyberImeFieldType fieldType;
  final CyberImeFieldProfile profile;
  final CyberImeCommitTarget commit;
  final CyberImeAction action;
  final VoidCallback? onAction;
  final VoidCallback? onPasswordReveal;

  late CyberImeKeyboardKind _kind;
  bool _shiftOn = false;
  bool _capsLock = false;
  bool _altGrOn = false;
  CyberImeJpInputMode _jpMode = CyberImeJpInputMode.english;

  /// Romaji buffer while soft JIS Japanese mode is composing.
  String _romajiBuffer = '';
  List<String> _candidates = const [];
  int _candidateIndex = 0;
  bool _candidatePickerOpen = false;

  CyberImeKeyboardKind get kind => _kind;

  bool get shiftOn => _shiftOn;

  bool get capsLock => _capsLock;

  bool get altGrOn => _altGrOn;

  /// Soft JIS: english vs romaji (hiragana) mode.
  CyberImeJpInputMode get jpInputMode => _jpMode;

  /// Shift visual “on” (single-shot or caps lock).
  bool get shiftActive => _shiftOn || _capsLock;

  bool get _isJis =>
      CyberImeRegionalLayoutRegistry.provider.profile ==
      CyberImeRegionalProfile.jis;

  bool get isRomajiMode =>
      _isJis && _jpMode != CyberImeJpInputMode.english;

  /// Current hiragana reading for the romaji buffer (may include latin tail).
  String get compositionText =>
      _romajiBuffer.isEmpty ? '' : CyberImeRomaji.toHiragana(_romajiBuffer);

  bool get hasComposition => _romajiBuffer.isNotEmpty;

  List<String> get candidates => _candidates;

  int get candidateIndex => _candidateIndex;

  bool get candidatePickerOpen => _candidatePickerOpen;

  String? get selectedCandidate {
    if (!_candidatePickerOpen || _candidates.isEmpty) return null;
    return _candidates[_candidateIndex.clamp(0, _candidates.length - 1)];
  }

  CyberImeLayout get layout {
    switch (_kind) {
      case CyberImeKeyboardKind.englishGlobal:
      case CyberImeKeyboardKind.chineseGlobal:
        return CyberImeLayouts.letters(
          bottomRow: profile.bottomRowProfile,
          kind: _kind,
        );
      case CyberImeKeyboardKind.symbolsPrimary:
        return CyberImeLayouts.symbolsPrimary();
      case CyberImeKeyboardKind.symbolsExtended:
        return CyberImeLayouts.symbolsExtended();
      case CyberImeKeyboardKind.numericDedicated:
        return CyberImeLayouts.numericDedicated();
    }
  }

  CyberImeKeyboardKind _initialLetterKind() {
    if (profile.initialLayoutId == CyberImeLayoutId.numericDedicatedB) {
      return CyberImeKeyboardKind.numericDedicated;
    }
    final preferred = CyberImeLanguageRegistry.provider.globalKind;
    if (preferred == CyberImeGlobalKind.chinese) {
      // Documented gap: fall back to English until task 3.6.
    }
    return CyberImeKeyboardKind.englishGlobal;
  }

  void onKeyTap(CyberImeKeyDef key) {
    switch (key.id) {
      case CyberImeKeyId.shift:
        if (_capsLock) {
          _capsLock = false;
          _shiftOn = false;
        } else {
          _shiftOn = !_shiftOn;
        }
        _altGrOn = false;
        notifyListeners();
        return;
      case CyberImeKeyId.altGr:
        _altGrOn = !_altGrOn;
        if (_altGrOn) {
          _shiftOn = false;
        }
        notifyListeners();
        return;
      case CyberImeKeyId.control:
      case CyberImeKeyId.alt:
        return;
      case CyberImeKeyId.capsLock:
        if (_isJis) {
          _jpMode = CyberImeJpInputMode.english;
          _clearComposition();
          onShiftLongPress();
          return;
        }
        onShiftLongPress();
        return;
      case CyberImeKeyId.hankakuZenkaku:
      case CyberImeKeyId.languageToggle:
        if (!_isJis) return;
        if (_jpMode == CyberImeJpInputMode.english) {
          _jpMode = CyberImeJpInputMode.hiragana;
        } else {
          _commitCompositionIfAny();
          _jpMode = CyberImeJpInputMode.english;
        }
        _shiftOn = false;
        _capsLock = false;
        _altGrOn = false;
        notifyListeners();
        return;
      case CyberImeKeyId.muhenkan:
        if (!_isJis) return;
        _commitCompositionIfAny();
        _jpMode = CyberImeJpInputMode.english;
        _shiftOn = false;
        _altGrOn = false;
        notifyListeners();
        return;
      case CyberImeKeyId.henkan:
        if (isRomajiMode && hasComposition) {
          _openOrCycleCandidates();
        }
        return;
      case CyberImeKeyId.kanaToggle:
        if (!_isJis) return;
        _jpMode = switch (_jpMode) {
          CyberImeJpInputMode.english ||
          CyberImeJpInputMode.katakana =>
            CyberImeJpInputMode.hiragana,
          CyberImeJpInputMode.hiragana => CyberImeJpInputMode.katakana,
        };
        _shiftOn = false;
        _capsLock = false;
        _altGrOn = false;
        notifyListeners();
        return;
      case CyberImeKeyId.tab:
        commit.insert('\t');
        return;
      case CyberImeKeyId.modeSwitch:
        _toggleMode();
        return;
      case CyberImeKeyId.symbolsMore:
        _kind = CyberImeKeyboardKind.symbolsExtended;
        notifyListeners();
        return;
      case CyberImeKeyId.backspace:
        if (isRomajiMode && hasComposition) {
          _romajiBuffer = _romajiBuffer.substring(0, _romajiBuffer.length - 1);
          _candidatePickerOpen = false;
          _candidates = const [];
          _candidateIndex = 0;
          notifyListeners();
          return;
        }
        commit.backspace();
        return;
      case CyberImeKeyId.clear:
        _clearComposition();
        commit.clear();
        return;
      case CyberImeKeyId.enter:
        if (isRomajiMode && hasComposition) {
          _commitComposition();
          return;
        }
        onAction?.call();
        return;
      case CyberImeKeyId.passwordReveal:
        onPasswordReveal?.call();
        return;
      case CyberImeKeyId.space:
        if (isRomajiMode && hasComposition) {
          _openOrCycleCandidates();
          return;
        }
        commit.insert(' ');
        return;
      case CyberImeKeyId.letter:
        _commitLetter(key);
        return;
      case CyberImeKeyId.digit:
      case CyberImeKeyId.custom:
      case CyberImeKeyId.at:
      case CyberImeKeyId.commaPeriod:
      case CyberImeKeyId.minus:
      case CyberImeKeyId.decimalPeriod:
        _commitText(key);
        return;
    }
  }

  /// Long-press Shift → caps lock (lws-ui).
  void onShiftLongPress() {
    _capsLock = !_capsLock;
    _shiftOn = _capsLock;
    notifyListeners();
  }

  /// Commit a floating-popup option string.
  void commitPopupText(String value) {
    if (value.isEmpty) return;
    if (isRomajiMode) {
      // Accents / latin from popup still go through romaji buffer as letters.
      for (final rune in value.runes) {
        final ch = String.fromCharCode(rune);
        if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
          _romajiBuffer += ch.toLowerCase();
        } else {
          _commitCompositionIfAny();
          commit.insert(ch);
        }
      }
      _candidatePickerOpen = false;
      _candidates = const [];
      notifyListeners();
      if (_shiftOn && !_capsLock) {
        _shiftOn = false;
        notifyListeners();
      }
      return;
    }
    commit.insert(value);
    if (_shiftOn && !_capsLock) {
      _shiftOn = false;
      notifyListeners();
    }
  }

  /// Long-press secondary (or lowercase) when popup is not used.
  void onKeyLongPressSecondary(CyberImeKeyDef key) {
    if (key.id == CyberImeKeyId.shift) {
      onShiftLongPress();
      return;
    }
    if (key.keyCode != null && _isJis) {
      final level = CyberImeKeyMaps.level(
        CyberImeRegionalProfile.jis,
        key.keyCode!,
      );
      if (_jpMode != CyberImeJpInputMode.english &&
          level.kanaShift != null &&
          level.kanaShift!.isNotEmpty) {
        final raw = level.kanaShift!;
        commitPopupText(
          _jpMode == CyberImeJpInputMode.katakana
              ? cyberImeToKatakana(raw)
              : raw,
        );
        return;
      }
    }
    if (key.secondary != null && key.secondary!.isNotEmpty) {
      commitPopupText(key.secondary!);
      return;
    }
    if (key.isLetter) {
      commitPopupText(key.primary.toLowerCase());
    }
  }

  void selectCandidate(int index) {
    if (index < 0 || index >= _candidates.length) return;
    _candidateIndex = index;
    _candidatePickerOpen = true;
    notifyListeners();
  }

  /// Commit a specific candidate chip (Settings / soft JIS bar).
  void commitCandidateAt(int index) {
    if (_candidates.isEmpty) {
      _candidates = CyberImeRomaji.candidatesFor(compositionText);
    }
    if (index < 0 || index >= _candidates.length) return;
    _candidateIndex = index;
    _candidatePickerOpen = true;
    _commitComposition();
  }

  void _toggleMode() {
    if (_kind == CyberImeKeyboardKind.englishGlobal ||
        _kind == CyberImeKeyboardKind.chineseGlobal) {
      _kind = CyberImeKeyboardKind.symbolsPrimary;
    } else if (_kind == CyberImeKeyboardKind.symbolsPrimary) {
      _kind = _initialLetterKind();
    } else if (_kind == CyberImeKeyboardKind.symbolsExtended) {
      _kind = CyberImeKeyboardKind.symbolsPrimary;
    }
    notifyListeners();
  }

  void _commitLetter(CyberImeKeyDef key) {
    final upper = _shiftOn || _capsLock;
    String ch;
    if (key.keyCode != null) {
      ch = CyberImeKeyMaps.resolve(
        CyberImeRegionalLayoutRegistry.provider.profile,
        key.keyCode!,
        shiftOn: upper,
        altGrOn: _altGrOn,
        // Soft JIS uses romaji — never KeyMap kana glyphs on letter tap.
        jpMode: CyberImeJpInputMode.english,
      );
    } else {
      ch = upper ? key.primary.toUpperCase() : key.primary.toLowerCase();
    }

    if (isRomajiMode && RegExp(r'^[A-Za-z]$').hasMatch(ch)) {
      _romajiBuffer += ch.toLowerCase();
      _candidatePickerOpen = false;
      _candidates = const [];
      _candidateIndex = 0;
      _consumeModifiersAfterChar();
      notifyListeners();
      return;
    }

    if (isRomajiMode && hasComposition) {
      _commitComposition();
    }
    commit.insert(ch);
    _consumeModifiersAfterChar();
  }

  void _commitText(CyberImeKeyDef key) {
    final policy = profile.numericPolicy;
    if (policy != null &&
        _kind == CyberImeKeyboardKind.numericDedicated &&
        !policy.shouldCommit(key, commit.text)) {
      return;
    }
    if (key.keyCode != null) {
      final upper = _shiftOn || _capsLock;
      final ch = CyberImeKeyMaps.resolve(
        CyberImeRegionalLayoutRegistry.provider.profile,
        key.keyCode!,
        shiftOn: upper,
        altGrOn: _altGrOn,
        jpMode: CyberImeJpInputMode.english,
      );
      // Digits/symbols do not clear an existing composition (plan §4.4).
      commit.insert(ch);
      _consumeModifiersAfterChar();
      return;
    }
    if (key.id == CyberImeKeyId.commaPeriod) {
      commit.insert(key.primary);
      return;
    }
    commit.insert(key.primary);
  }

  void _openOrCycleCandidates() {
    final reading = compositionText;
    if (reading.isEmpty) return;
    if (!_candidatePickerOpen || _candidates.isEmpty) {
      _candidates = CyberImeRomaji.candidatesFor(reading);
      _candidateIndex = 0;
      _candidatePickerOpen = true;
    } else {
      _candidateIndex = (_candidateIndex + 1) % _candidates.length;
    }
    notifyListeners();
  }

  void _commitComposition() {
    final text = selectedCandidate ?? compositionText;
    if (text.isNotEmpty) {
      commit.insert(text);
    }
    _clearComposition();
    notifyListeners();
  }

  void _commitCompositionIfAny() {
    if (!hasComposition) return;
    _commitComposition();
  }

  void _clearComposition() {
    _romajiBuffer = '';
    _candidates = const [];
    _candidateIndex = 0;
    _candidatePickerOpen = false;
  }

  void _consumeModifiersAfterChar() {
    var changed = false;
    if (_shiftOn && !_capsLock) {
      _shiftOn = false;
      changed = true;
    }
    if (_altGrOn) {
      _altGrOn = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
