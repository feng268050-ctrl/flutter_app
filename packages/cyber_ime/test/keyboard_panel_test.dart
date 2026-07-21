import 'package:cyber_ime/cyber_ime.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cyberImeSelectionIndexForX', () {
    test('maps three zones across key width', () {
      expect(
        cyberImeSelectionIndexForX(x: 50, keyWidth: 300, optionCount: 3),
        0,
      );
      expect(
        cyberImeSelectionIndexForX(x: 150, keyWidth: 300, optionCount: 3),
        1,
      );
      expect(
        cyberImeSelectionIndexForX(x: 250, keyWidth: 300, optionCount: 3),
        2,
      );
    });

    test('maps two zones for dual popup', () {
      expect(
        cyberImeSelectionIndexForX(x: 40, keyWidth: 200, optionCount: 2),
        0,
      );
      expect(
        cyberImeSelectionIndexForX(x: 160, keyWidth: 200, optionCount: 2),
        1,
      );
    });

    test('default popup index', () {
      expect(cyberImeDefaultPopupIndex(3), 1);
      expect(cyberImeDefaultPopupIndex(2), 0);
      expect(cyberImeDefaultPopupIndex(1), 0);
    });
  });

  testWidgets('Keyboard A toggles to symbols and back', (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberImeKeyboardPanel(controller: kb),
        ),
      ),
    );

    expect(find.text('q'), findsOneWidget);
    await tester.tap(find.text('123'));
    await tester.pump();
    expect(find.text('#+='), findsOneWidget);
    await tester.tap(find.text('ABC'));
    await tester.pump();
    expect(find.text('q'), findsOneWidget);
    kb.dispose();
  });

  testWidgets('Keyboard B clear and enter', (tester) async {
    final ctrl = TextEditingController(text: '42');
    var entered = false;
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.number,
      commit: CyberImeControllerCommit(ctrl),
      onAction: () => entered = true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberImeKeyboardPanel(controller: kb),
        ),
      ),
    );

    expect(find.text('C'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(ctrl.text, '');

    await tester.tap(find.byIcon(Icons.keyboard_return));
    await tester.pump();
    expect(entered, isTrue);
    kb.dispose();
  });

  testWidgets('letter long-press shows popup; release commits secondary',
      (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CyberImeKeyboardPanel(controller: kb)),
      ),
    );

    final center = tester.getCenter(find.text('q'));
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // Popup shows Q / 1 / q — secondary "1" highlighted by default.
    expect(find.text('1'), findsWidgets);
    await gesture.up();
    await tester.pump();
    expect(ctrl.text, '1');
    kb.dispose();
  });

  testWidgets('letter long-press slide left commits uppercase', (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CyberImeKeyboardPanel(controller: kb)),
      ),
    );

    final keyFinder = find.byWidgetPredicate(
      (w) => w is CyberImeKeyCap && w.keyDef.primary == 'Q',
    );
    final rect = tester.getRect(keyFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // Slide to left third of the key → uppercase Q (lws-ui selectionIndexForX).
    await gesture.moveTo(Offset(rect.left + rect.width * 0.05, rect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ctrl.text, 'Q');
    kb.dispose();
  });

  testWidgets('period key shows comma secondary hint', (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CyberImeKeyboardPanel(controller: kb)),
      ),
    );

    expect(find.text('.'), findsOneWidget);
    expect(find.text(','), findsOneWidget);
    kb.dispose();
  });

  testWidgets('panel has no nested CyberBackdropBlur; backdrop is separate',
      (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              const CyberImeKeyboardBackdrop(),
              CyberImeKeyboardPanel(controller: kb),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CyberImeKeyboardBackdrop), findsOneWidget);
    expect(find.byType(CyberBackdropBlur), findsOneWidget);
    expect(find.text('q'), findsOneWidget);
    kb.dispose();
  });
}