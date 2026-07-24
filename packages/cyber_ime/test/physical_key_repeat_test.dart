import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('software key-repeat inserts while printable key held',
      (tester) async {
    final focus = FocusNode();
    final ctrl = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(ctrl.dispose);

    final repeat = CyberImePhysicalKeyRepeat(
      delay: const Duration(milliseconds: 100),
      interval: const Duration(milliseconds: 50),
    );
    addTearDown(repeat.detach);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: focus,
          autofocus: true,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);

    repeat.attach(focusNode: focus, controller: ctrl);

    expect(
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          character: 'a',
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
    // First glyph is normally from EditableText; synthesizer starts after delay.
    expect(ctrl.text, isEmpty);

    await tester.pump(const Duration(milliseconds: 100));
    expect(ctrl.text, 'a');
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.text, 'aa');
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.text, 'aaa');

    expect(
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(ctrl.text, 'aaa');
  });

  testWidgets('real KeyRepeatEvent cancels software synthesizer',
      (tester) async {
    final focus = FocusNode();
    final ctrl = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(ctrl.dispose);

    final repeat = CyberImePhysicalKeyRepeat(
      delay: const Duration(milliseconds: 80),
      interval: const Duration(milliseconds: 40),
    );
    addTearDown(repeat.detach);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: focus,
          autofocus: true,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repeat.attach(focusNode: focus, controller: ctrl);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyB,
        logicalKey: LogicalKeyboardKey.keyB,
        character: 'b',
        timeStamp: Duration.zero,
      ),
    );

    // Embedder starts delivering real repeats before our delay fires.
    HardwareKeyboard.instance.handleKeyEvent(
      const KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyB,
        logicalKey: LogicalKeyboardKey.keyB,
        character: 'b',
        timeStamp: Duration(milliseconds: 1),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(ctrl.text, isEmpty);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyB,
        logicalKey: LogicalKeyboardKey.keyB,
        timeStamp: Duration(milliseconds: 2),
      ),
    );
  });

  testWidgets('software key-repeat deletes while Backspace held',
      (tester) async {
    final focus = FocusNode();
    final ctrl = TextEditingController(text: 'abcd');
    ctrl.selection = const TextSelection.collapsed(offset: 4);
    addTearDown(focus.dispose);
    addTearDown(ctrl.dispose);

    final repeat = CyberImePhysicalKeyRepeat(
      delay: const Duration(milliseconds: 100),
      interval: const Duration(milliseconds: 50),
    );
    addTearDown(repeat.detach);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: focus,
          autofocus: true,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repeat.attach(focusNode: focus, controller: ctrl);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.backspace,
        logicalKey: LogicalKeyboardKey.backspace,
        timeStamp: Duration.zero,
      ),
    );
    expect(ctrl.text, 'abcd');

    await tester.pump(const Duration(milliseconds: 100));
    expect(ctrl.text, 'abc');
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.text, 'ab');
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.text, 'a');

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.backspace,
        logicalKey: LogicalKeyboardKey.backspace,
        timeStamp: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(ctrl.text, 'a');
  });

  testWidgets('software key-repeat forward-deletes while Delete held',
      (tester) async {
    final focus = FocusNode();
    final ctrl = TextEditingController(text: 'abcd');
    ctrl.selection = const TextSelection.collapsed(offset: 1);
    addTearDown(focus.dispose);
    addTearDown(ctrl.dispose);

    final repeat = CyberImePhysicalKeyRepeat(
      delay: const Duration(milliseconds: 100),
      interval: const Duration(milliseconds: 50),
    );
    addTearDown(repeat.detach);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: focus,
          autofocus: true,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repeat.attach(focusNode: focus, controller: ctrl);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.delete,
        logicalKey: LogicalKeyboardKey.delete,
        timeStamp: Duration.zero,
      ),
    );
    expect(ctrl.text, 'abcd');

    await tester.pump(const Duration(milliseconds: 100));
    expect(ctrl.text, 'acd');
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.text, 'ad');
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.text, 'a');

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.delete,
        logicalKey: LogicalKeyboardKey.delete,
        timeStamp: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(ctrl.text, 'a');
  });

  testWidgets('software key-repeat moves caret while ArrowLeft held',
      (tester) async {
    final focus = FocusNode();
    final ctrl = TextEditingController(text: 'abcd');
    ctrl.selection = const TextSelection.collapsed(offset: 4);
    addTearDown(focus.dispose);
    addTearDown(ctrl.dispose);

    final repeat = CyberImePhysicalKeyRepeat(
      delay: const Duration(milliseconds: 100),
      interval: const Duration(milliseconds: 50),
    );
    addTearDown(repeat.detach);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          focusNode: focus,
          autofocus: true,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repeat.attach(focusNode: focus, controller: ctrl);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      ),
    );
    expect(ctrl.selection.baseOffset, 4);

    await tester.pump(const Duration(milliseconds: 100));
    expect(ctrl.selection.baseOffset, 3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.selection.baseOffset, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(ctrl.selection.baseOffset, 1);

    HardwareKeyboard.instance.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(ctrl.selection.baseOffset, 1);
  });
}
