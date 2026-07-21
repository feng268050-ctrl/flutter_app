import 'package:flutter/widgets.dart';

/// Commit bridge for insert / backspace / clear against a text field.
abstract class CyberImeCommitTarget {
  String get text;
  void insert(String value);
  void backspace();
  void clear();
}

/// [TextEditingController]-backed commit target.
class CyberImeControllerCommit implements CyberImeCommitTarget {
  CyberImeControllerCommit(this.controller);

  final TextEditingController controller;

  @override
  String get text => controller.text;

  @override
  void insert(String value) {
    final sel = controller.selection;
    final t = controller.text;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final next = t.replaceRange(start, end, value);
    final caret = start + value.length;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
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
      );
      return;
    }
    final caret = sel.isValid ? sel.start : t.length;
    if (caret <= 0) return;
    final next = t.replaceRange(caret - 1, caret, '');
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret - 1),
    );
  }

  @override
  void clear() {
    controller.clear();
  }
}
