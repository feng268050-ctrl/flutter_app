import 'package:flutter/widgets.dart';

/// Commit bridge for insert / backspace / clear / caret move against a text field.
abstract class CyberImeCommitTarget {
  String get text;
  void insert(String value);
  void backspace();
  void clear();

  /// Move the caret by [delta] characters (negative = left). Clamped to text.
  void moveCursorBy(int delta);
}

/// [TextEditingController]-backed commit target.
class CyberImeControllerCommit implements CyberImeCommitTarget {
  CyberImeControllerCommit(this.controller);

  final TextEditingController controller;

  @override
  String get text => controller.text;

  /// Soft CyberIME never intentionally select-all before a key commit.
  ///
  /// On flutter-elinux (especially [obscureText] Wi‑Fi password fields),
  /// [EditableText] often expands selection to `0..text.length` between
  /// commits. Treating that as a caret-at-end append avoids replace-all so
  /// the field appears stuck at 1–2 characters.
  static bool isSpuriousSelectAll(TextSelection sel, String text) {
    return text.isNotEmpty &&
        sel.isValid &&
        !sel.isCollapsed &&
        sel.start == 0 &&
        sel.end == text.length;
  }

  @override
  void insert(String value) {
    final sel = controller.selection;
    final t = controller.text;
    final int start;
    final int end;
    if (!sel.isValid) {
      start = end = t.length;
    } else if (isSpuriousSelectAll(sel, t)) {
      start = end = t.length;
    } else {
      start = sel.start;
      end = sel.end;
    }
    final next = t.replaceRange(start, end, value);
    final caret = start + value.length;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
  }

  @override
  void backspace() {
    final sel = controller.selection;
    final t = controller.text;
    if (sel.isValid && sel.start != sel.end) {
      final next = t.replaceRange(sel.start, sel.end, '');
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
        composing: TextRange.empty,
      );
      return;
    }
    final caret = sel.isValid ? sel.start : t.length;
    if (caret <= 0) return;
    final next = t.replaceRange(caret - 1, caret, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret - 1),
      composing: TextRange.empty,
    );
  }

  @override
  void clear() {
    controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );
  }

  @override
  void moveCursorBy(int delta) {
    if (delta == 0) {
      return;
    }
    final t = controller.text;
    final sel = controller.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final offset = delta < 0 ? sel.start : sel.end;
      controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: offset),
        composing: TextRange.empty,
      );
      return;
    }
    final caret = sel.isValid ? sel.baseOffset : t.length;
    final next = (caret + delta).clamp(0, t.length);
    if (next == caret) {
      return;
    }
    controller.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: next),
      composing: TextRange.empty,
    );
  }
}
