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

  CyberImeKeyboardKind get kind => _kind;

  bool get shiftOn => _shiftOn;

  bool get capsLock => _capsLock;

  bool get altGrOn => _altGrOn;

  /// JP input mode for key-cap labels (always 英数 on soft Keyboard A).
  CyberImeJpInputMode get jpInputMode => CyberImeJpInputMode.english;

  /// Shift visual “on” (single-shot or caps lock).
  bool get shiftActive => _shiftOn || _capsLock;

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
      case CyberImeKeyId.hankakuZenkaku:
      case CyberImeKeyId.languageToggle:
      case CyberImeKeyId.muhenkan:
      case CyberImeKeyId.henkan:
      case CyberImeKeyId.kanaToggle:
        return;
      case CyberImeKeyId.capsLock:
        onShiftLongPress();
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

  /// Soft Space trackpad: move caret by [delta] characters (no text change).
  ///
  /// Invokes [onSpaceTrackpadCursorMove] after the selection update so the
  /// host field can refresh caret chrome.
  void moveCursorBy(int delta) {
    if (delta == 0) {
      return;
    }
    commit.moveCursorBy(delta);
    onSpaceTrackpadCursorMove?.call(delta);
  }

  /// Soft Space long-press entered Cursor Trackpad Mode.
  void beginSpaceTrackpad() => onSpaceTrackpadStart?.call();

  /// Soft Space trackpad pointer up / cancel.
  void endSpaceTrackpad() => onSpaceTrackpadEnd?.call();

  /// Host (typically [CyberImeTextField]) caret chrome hooks.
  VoidCallback? onSpaceTrackpadStart;
  ValueChanged<int>? onSpaceTrackpadCursorMove;
  VoidCallback? onSpaceTrackpadEnd;

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
        jpMode: CyberImeJpInputMode.english,
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
      final ch = CyberImeKeyMaps.resolve(
        CyberImeRegionalLayoutRegistry.provider.profile,
        key.keyCode!,
        shiftOn: upper,
        altGrOn: _altGrOn,
        jpMode: CyberImeJpInputMode.english,
      );
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
