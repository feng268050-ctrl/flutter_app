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

  CyberImeKeyboardKind get kind => _kind;

  bool get shiftOn => _shiftOn;

  bool get capsLock => _capsLock;

  bool get altGrOn => _altGrOn;

  /// JIS 英数 / ひらがな / カタカナ (ignored for non-JIS profiles).
  CyberImeJpInputMode get jpInputMode => _jpMode;

  /// Shift visual “on” (single-shot or caps lock).
  bool get shiftActive => _shiftOn || _capsLock;

  bool get _isJis =>
      CyberImeRegionalLayoutRegistry.provider.profile ==
      CyberImeRegionalProfile.jis;

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
    // ChineseGlobal deferred — always English letter caps in v1.
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
        // Soft layout geometry only — no chorded shortcuts in v1.
        return;
      case CyberImeKeyId.capsLock:
        if (_isJis) {
          // 英数 — force Latin mode; keep caps lock toggle for Latin case.
          _jpMode = CyberImeJpInputMode.english;
          onShiftLongPress();
          return;
        }
        onShiftLongPress();
        return;
      case CyberImeKeyId.hankakuZenkaku:
        if (!_isJis) return;
        // Toggle 英数 ↔ ひらがな (from カタカナ → 英数).
        _jpMode = _jpMode == CyberImeJpInputMode.english
            ? CyberImeJpInputMode.hiragana
            : CyberImeJpInputMode.english;
        _shiftOn = false;
        _capsLock = false;
        _altGrOn = false;
        notifyListeners();
        return;
      case CyberImeKeyId.muhenkan:
        if (!_isJis) return;
        _jpMode = CyberImeJpInputMode.english;
        _shiftOn = false;
        _altGrOn = false;
        notifyListeners();
        return;
      case CyberImeKeyId.henkan:
        // No candidate / composition engine in soft v1.
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
        commit.backspace();
        return;
      case CyberImeKeyId.clear:
        commit.clear();
        return;
      case CyberImeKeyId.enter:
        onAction?.call();
        return;
      case CyberImeKeyId.passwordReveal:
        onPasswordReveal?.call();
        return;
      case CyberImeKeyId.space:
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
        jpMode: _isJis ? _jpMode : CyberImeJpInputMode.english,
      );
    } else {
      ch = upper ? key.primary.toUpperCase() : key.primary.toLowerCase();
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
      commit.insert(
        CyberImeKeyMaps.resolve(
          CyberImeRegionalLayoutRegistry.provider.profile,
          key.keyCode!,
          shiftOn: upper,
          altGrOn: _altGrOn,
          jpMode: _isJis ? _jpMode : CyberImeJpInputMode.english,
        ),
      );
      _consumeModifiersAfterChar();
      return;
    }
    if (key.id == CyberImeKeyId.commaPeriod) {
      commit.insert(key.primary);
      return;
    }
    commit.insert(key.primary);
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
