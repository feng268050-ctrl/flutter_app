import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum _RepeatAction {
  insert,
  backspace,
  delete,
  arrowLeft,
  arrowRight,
  arrowUp,
  arrowDown,
}

/// Software key-repeat for physical keyboards.
///
/// Wayland expects the **client** to implement repeat from
/// `wl_keyboard.repeat_info`. flutter-elinux currently no-ops that listener, so
/// held keys never emit [KeyRepeatEvent]. This binder synthesizes edits / caret
/// moves into a [TextEditingController] while a printable key, Backspace,
/// Delete, or arrow key is held.
///
/// If the embedder later delivers [KeyRepeatEvent], software repeat is cancelled
/// to avoid double-edit.
class CyberImePhysicalKeyRepeat {
  CyberImePhysicalKeyRepeat({
    this.delay = const Duration(milliseconds: 500),
    this.interval = const Duration(milliseconds: 40),
  });

  /// Delay after first [KeyDownEvent] before repeating starts.
  final Duration delay;

  /// Interval between subsequent edits / caret moves.
  final Duration interval;

  FocusNode? _focus;
  TextEditingController? _controller;
  bool _attached = false;

  Timer? _delayTimer;
  Timer? _periodTimer;
  LogicalKeyboardKey? _heldKey;
  _RepeatAction? _action;
  String? _heldChar;

  /// Start listening. Safe to call once; call [detach] from [State.dispose].
  void attach({
    required FocusNode focusNode,
    required TextEditingController controller,
  }) {
    if (_attached) {
      detach();
    }
    _focus = focusNode;
    _controller = controller;
    _attached = true;
    HardwareKeyboard.instance.addHandler(_onKey);
    _focus!.addListener(_onFocus);
  }

  void detach() {
    if (!_attached) {
      return;
    }
    HardwareKeyboard.instance.removeHandler(_onKey);
    _focus?.removeListener(_onFocus);
    _cancel();
    _focus = null;
    _controller = null;
    _attached = false;
  }

  void _onFocus() {
    if (_focus?.hasFocus != true) {
      _cancel();
    }
  }

  bool _onKey(KeyEvent event) {
    if (_focus?.hasFocus != true) {
      return false;
    }

    if (event is KeyRepeatEvent) {
      // Real embedder repeat — stop synthesizing.
      _cancel();
      return false;
    }

    if (event is KeyUpEvent) {
      if (_heldKey == event.logicalKey) {
        _cancel();
      }
      return false;
    }

    if (event is! KeyDownEvent) {
      return false;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _arm(key, _RepeatAction.backspace, null);
      return false;
    }
    if (key == LogicalKeyboardKey.delete) {
      _arm(key, _RepeatAction.delete, null);
      return false;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _arm(key, _RepeatAction.arrowLeft, null);
      return false;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _arm(key, _RepeatAction.arrowRight, null);
      return false;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _arm(key, _RepeatAction.arrowUp, null);
      return false;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _arm(key, _RepeatAction.arrowDown, null);
      return false;
    }

    final ch = event.character;
    if (ch == null || ch.isEmpty) {
      _cancel();
      return false;
    }
    // Skip control / private-use characters.
    if (ch.codeUnitAt(0) < 0x20) {
      _cancel();
      return false;
    }

    _arm(key, _RepeatAction.insert, ch);
    return false;
  }

  void _arm(LogicalKeyboardKey key, _RepeatAction action, String? ch) {
    _cancel();
    _heldKey = key;
    _action = action;
    _heldChar = ch;
    _delayTimer = Timer(delay, () {
      _apply();
      _periodTimer = Timer.periodic(interval, (_) => _apply());
    });
  }

  void _apply() {
    final focus = _focus;
    final controller = _controller;
    final action = _action;
    if (focus == null ||
        controller == null ||
        action == null ||
        !focus.hasFocus) {
      _cancel();
      return;
    }

    switch (action) {
      case _RepeatAction.insert:
        _insert(controller, _heldChar!);
      case _RepeatAction.backspace:
        _backspace(controller);
      case _RepeatAction.delete:
        _delete(controller);
      case _RepeatAction.arrowLeft:
        _moveCaret(controller, -1);
      case _RepeatAction.arrowRight:
        _moveCaret(controller, 1);
      case _RepeatAction.arrowUp:
        _moveVertical(controller, up: true);
      case _RepeatAction.arrowDown:
        _moveVertical(controller, up: false);
    }
  }

  void _insert(TextEditingController controller, String ch) {
    final value = controller.value;
    final selection = value.selection;
    if (!selection.isValid) {
      final text = '${value.text}$ch';
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final newText = value.text.replaceRange(start, end, ch);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + ch.length),
    );
  }

  void _backspace(TextEditingController controller) {
    final sel = controller.selection;
    final t = controller.text;
    if (sel.isValid && sel.start != sel.end) {
      final next = t.replaceRange(sel.start, sel.end, '');
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }
    final caret = sel.isValid ? sel.start : t.length;
    if (caret <= 0) {
      return;
    }
    final next = t.replaceRange(caret - 1, caret, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret - 1),
    );
  }

  void _delete(TextEditingController controller) {
    final sel = controller.selection;
    final t = controller.text;
    if (sel.isValid && sel.start != sel.end) {
      final next = t.replaceRange(sel.start, sel.end, '');
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }
    final caret = sel.isValid ? sel.start : t.length;
    if (caret >= t.length) {
      return;
    }
    final next = t.replaceRange(caret, caret + 1, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  void _moveCaret(TextEditingController controller, int delta) {
    final t = controller.text;
    final sel = controller.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final offset = delta < 0 ? sel.start : sel.end;
      controller.selection = TextSelection.collapsed(offset: offset);
      return;
    }
    final caret = sel.isValid ? sel.baseOffset : t.length;
    final next = (caret + delta).clamp(0, t.length);
    if (next == caret) {
      return;
    }
    controller.selection = TextSelection.collapsed(offset: next);
  }

  /// Line-aware up/down: previous/next line, preserving column when possible.
  /// Single-line fields collapse to start (up) or end (down).
  void _moveVertical(TextEditingController controller, {required bool up}) {
    final t = controller.text;
    final sel = controller.selection;
    final caret = sel.isValid
        ? (up ? math.min(sel.start, sel.end) : math.max(sel.start, sel.end))
        : (up ? 0 : t.length);

    final curLineStart =
        caret == 0 ? 0 : t.lastIndexOf('\n', caret - 1) + 1;
    final column = caret - curLineStart;

    if (up) {
      if (curLineStart == 0) {
        if (caret != 0) {
          controller.selection = const TextSelection.collapsed(offset: 0);
        }
        return;
      }
      final prevBreak = curLineStart <= 1
          ? -1
          : t.lastIndexOf('\n', curLineStart - 2);
      final prevStart = prevBreak + 1;
      final prevEnd = curLineStart - 1; // index of `\n` before this line
      final next = math.min(prevStart + column, prevEnd);
      controller.selection = TextSelection.collapsed(offset: next);
      return;
    }

    final curBreak = t.indexOf('\n', caret);
    if (curBreak < 0) {
      if (caret != t.length) {
        controller.selection = TextSelection.collapsed(offset: t.length);
      }
      return;
    }
    final nextStart = curBreak + 1;
    final nextBreak = t.indexOf('\n', nextStart);
    final nextEnd = nextBreak < 0 ? t.length : nextBreak;
    final next = math.min(nextStart + column, nextEnd);
    controller.selection = TextSelection.collapsed(offset: next);
  }

  void _cancel() {
    _delayTimer?.cancel();
    _periodTimer?.cancel();
    _delayTimer = null;
    _periodTimer = null;
    _heldKey = null;
    _action = null;
    _heldChar = null;
  }
}
