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

  testWidgets('symbol key shows its implemented second function', (tester) async {
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

    await tester.tap(find.text('123'));
    await tester.pump();

    // The apostrophe key has an existing backtick second function. It must be
    // visible on the keycap, not only available from its long-press popup.
    expect(find.text('`'), findsOneWidget);
    kb.dispose();
  });

  testWidgets('DE regional profile shows QWERTZ letter caps', (tester) async {
    CyberImeRegionalLayoutRegistry.register(
      const CyberImeFixedRegionalLayoutProvider(CyberImeRegionalProfile.qwertz),
    );
    addTearDown(() => CyberImeRegionalLayoutRegistry.register(null));

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

    expect(find.text('z'), findsWidgets); // physical Y → z
    expect(find.text('y'), findsWidgets); // physical Z → y
    expect(find.text('ä'), findsOneWidget);
    expect(find.text('ö'), findsOneWidget);
    expect(find.text('ü'), findsOneWidget);
    expect(find.text('ß'), findsOneWidget);
    expect(find.text('F1'), findsNothing);
    expect(find.text('F12'), findsNothing);
    // No dedicated numpad chrome on Keyboard A.
    expect(find.text('00'), findsNothing);
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

  testWidgets('letter long-press slide left commits lowercase', (tester) async {
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
    expect(find.text('Q'), findsWidgets);
    // Soft pad popup [q, Q]: left half → lowercase.
    await gesture.moveTo(Offset(rect.left + rect.width * 0.05, rect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ctrl.text, 'q');
    kb.dispose();
  });

  testWidgets('letter long-press slide right commits uppercase', (tester) async {
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
    await gesture.moveTo(Offset(rect.left + rect.width * 0.95, rect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ctrl.text, 'Q');
    kb.dispose();
  });

  testWidgets('QWERTZ A long-press offers umlaut candidates', (tester) async {
    CyberImeRegionalLayoutRegistry.register(
      const CyberImeFixedRegionalLayoutProvider(CyberImeRegionalProfile.qwertz),
    );
    addTearDown(() => CyberImeRegionalLayoutRegistry.register(null));

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
      (w) => w is CyberImeKeyCap && w.keyDef.primary == 'A',
    );
    final rect = tester.getRect(keyFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('ä'), findsWidgets);
    // Options [a, ä, A, Ä] — second quarter commits ä.
    await gesture.moveTo(Offset(rect.left + rect.width * 0.35, rect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(ctrl.text, 'ä');
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
    expect(find.byType(CyberImeKeyboardTopEdge), findsOneWidget);
    expect(find.text('q'), findsOneWidget);
    kb.dispose();
  });

  testWidgets('CyberImeLayoutPreview paints shared backdrop under keys',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ColoredBox(
            color: Colors.teal,
            child: CyberImeLayoutPreview(profile: CyberImeRegionalProfile.qwerty),
          ),
        ),
      ),
    );

    expect(find.byType(CyberImeKeyboardBackdrop), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(CyberButton), findsWidgets);
  });

  testWidgets('CyberImeLayoutPreview shows soft QWERTY without typewriter chrome',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberImeLayoutPreview(profile: CyberImeRegionalProfile.qwerty),
        ),
      ),
    );

    expect(find.text('q'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
    expect(find.text('('), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return), findsOneWidget);
    expect(find.text('Ctrl'), findsNothing);
    expect(find.text('123'), findsOneWidget);
  });

  testWidgets('QWERTZ soft preview swaps Y/Z', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberImeLayoutPreview(profile: CyberImeRegionalProfile.qwertz),
        ),
      ),
    );
    expect(find.byIcon(Icons.keyboard_return), findsOneWidget);
    expect(find.text('z'), findsWidgets);
    expect(find.text('y'), findsWidgets);
    expect(find.text('ä'), findsOneWidget);
    expect(find.text('ö'), findsOneWidget);
    expect(find.text('ü'), findsOneWidget);
    expect(find.text('ß'), findsOneWidget);
    expect(find.text('Ctrl'), findsNothing);
  });

  testWidgets('AZERTY panel and preview show accented second functions',
      (tester) async {
    CyberImeRegionalLayoutRegistry.register(
      const CyberImeFixedRegionalLayoutProvider(CyberImeRegionalProfile.azerty),
    );
    addTearDown(() => CyberImeRegionalLayoutRegistry.register(null));

    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    addTearDown(kb.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CyberImeKeyboardPanel(controller: kb)),
      ),
    );

    for (final character in ['à', 'é', 'ô', 'ç']) {
      expect(find.text(character), findsOneWidget);
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberImeLayoutPreview(profile: CyberImeRegionalProfile.azerty),
        ),
      ),
    );

    for (final character in ['à', 'é', 'ô', 'ç']) {
      expect(find.text(character), findsOneWidget);
    }
  });

  testWidgets('CyberImeLayoutChooser switches Segment and preview',
      (tester) async {
    var selected = CyberImeRegionalProfile.qwerty;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CyberImeLayoutChooser(
                selected: selected,
                onSelected: (p) => setState(() => selected = p),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Default'), findsNothing);
    expect(find.text('软件键盘布局预览'), findsOneWidget);
    expect(find.text('q'), findsWidgets);
    await tester.tap(find.text('QWERTZ'));
    await tester.pumpAndSettle();
    expect(selected, CyberImeRegionalProfile.qwertz);
    expect(find.text('长按可输入重音字符'), findsOneWidget);
    expect(find.text('Ctrl'), findsNothing);
  });

  testWidgets('password visibility toggle works while IME is open',
      (tester) async {
    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(false),
    );
    addTearDown(() => CyberImePhysicalKeyboard.register(null));

    final ctrl = TextEditingController(text: 'secret');
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(bottom: 320),
            child: CyberImeTextField(
              fieldType: CyberImeFieldType.wifi,
              controller: ctrl,
              obscureText: true,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Soft show is async (physical-keyboard probe).
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('q'), findsWidgets);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    // IME must stay up (eye must not steal focus / full-screen scrim must not
    // eat the tap).
    expect(find.text('q'), findsWidgets);
  });

  testWidgets('physical keyboard inserts into CyberImeTextField',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(bottom: 320),
            child: CyberImeTextField(
              fieldType: CyberImeFieldType.text,
              controller: ctrl,
              focusNode: focus,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);

    // Regression: readOnly:true blocked hardware/XKB (and TextInput) inserts.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isFalse);

    // TextInput path used by hardware/XKB when not readOnly.
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    expect(ctrl.text, 'ab');
  });

  testWidgets('soft IME hidden when physical keyboard present', (tester) async {
    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(true),
    );
    addTearDown(() => CyberImePhysicalKeyboard.register(null));

    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(bottom: 320),
            child: CyberImeTextField(
              fieldType: CyberImeFieldType.text,
              controller: ctrl,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('q'), findsNothing);
    expect(find.byType(CyberImeKeyboardPanel), findsNothing);
  });

  testWidgets('soft IME shown when no physical keyboard', (tester) async {
    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(false),
    );
    addTearDown(() => CyberImePhysicalKeyboard.register(null));

    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(bottom: 320),
            child: CyberImeTextField(
              fieldType: CyberImeFieldType.text,
              controller: ctrl,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('q'), findsWidgets);
  });
}
