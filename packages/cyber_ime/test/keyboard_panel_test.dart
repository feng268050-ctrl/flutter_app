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

  group('cyberImeCursorStepsForDx', () {
    test('accumulates residual into discrete steps', () {
      var residual = 0.0;
      var r = cyberImeCursorStepsForDx(dx: 10, residual: residual);
      expect(r.steps, 0);
      residual = r.residual;

      r = cyberImeCursorStepsForDx(dx: 5, residual: residual);
      expect(r.steps, 1);
      expect(r.residual, closeTo(1.0, 0.001));

      r = cyberImeCursorStepsForDx(dx: -20, residual: 0);
      expect(r.steps, -1);
      expect(r.residual, closeTo(-6.0, 0.001));
    });

    test('large displacement yields multiple steps', () {
      final r = cyberImeCursorStepsForDx(dx: 45, residual: 0);
      expect(r.steps, 3);
      expect(r.residual, closeTo(3.0, 0.001));
    });
  });

  group('cyberImeClampAlternatePopupLeft', () {
    test('keeps 2px inset at left and right edges', () {
      expect(
        cyberImeClampAlternatePopupLeft(
          preferredCenterX: 20,
          childWidth: 160,
          parentWidth: 800,
        ),
        2,
      );
      expect(
        cyberImeClampAlternatePopupLeft(
          preferredCenterX: 780,
          childWidth: 160,
          parentWidth: 800,
        ),
        800 - 160 - 2,
      );
    });

    test('centers when child is wider than the safe area', () {
      expect(
        cyberImeClampAlternatePopupLeft(
          preferredCenterX: 400,
          childWidth: 798,
          parentWidth: 800,
        ),
        (800 - 798) / 2,
      );
    });
  });

  group('cyberImeAlternatePopupTop', () {
    test('uses offset when popup is shorter than the lift', () {
      expect(
        cyberImeAlternatePopupTop(keyTopY: 200, popupHeight: 40),
        200 - kCyberImeAlternatePopupOffsetAboveKey,
      );
    });

    test('lifts further so a tall popup does not overlap the key', () {
      expect(
        cyberImeAlternatePopupTop(keyTopY: 200, popupHeight: 70),
        200 - 70,
      );
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

  testWidgets('quote key keeps backtick for long-press only', (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    addTearDown(kb.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberImeKeyboardPanel(controller: kb),
        ),
      ),
    );

    await tester.tap(find.text('123'));
    await tester.pump();

    final quoteFinder = find.byWidgetPredicate(
      (w) =>
          w is CyberImeKeyCap &&
          w.keyDef.primary == "'" &&
          w.keyDef.secondary == '`',
    );
    expect(quoteFinder, findsOneWidget);
    // lws-ui: custom secondary is not painted on the key face.
    expect(find.text('`'), findsNothing);

    final rect = tester.getRect(quoteFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('`'), findsWidgets);
    await gesture.up();
    await tester.pump();
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
    for (final character in ['1', '@', '€', '*', '?']) {
      expect(find.text(character), findsWidgets);
    }
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

  testWidgets('edge-key alternate popup keeps 2px screen inset',
      (tester) async {
    final ctrl = TextEditingController();
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    addTearDown(kb.dispose);

    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CyberImeKeyboardPanel(controller: kb, height: 300),
          ),
        ),
      ),
    );

    final keyFinder = find.byWidgetPredicate(
      (w) => w is CyberImeKeyCap && w.keyDef.primary == 'Q',
    );
    final rect = tester.getRect(keyFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    final popup = find.byType(CyberImeAlternatePopup);
    expect(popup, findsOneWidget);
    final popupRect = tester.getRect(popup);
    expect(
        popupRect.left, greaterThanOrEqualTo(kCyberImeAlternatePopupEdgeInset));
    expect(
      popupRect.right,
      lessThanOrEqualTo(800 - kCyberImeAlternatePopupEdgeInset),
    );
    // Keyboard sits at the bottom — popup must clear the keycap vertically.
    expect(popupRect.bottom, lessThanOrEqualTo(rect.top + 0.5));
    expect(popupRect.height, lessThan(100));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('letter long-press slide right commits uppercase',
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
    // Options [a, ä, á, …] — select index 1 (ä).
    await gesture.moveTo(
      Offset(rect.left + rect.width * (1.5 / 10), rect.center.dy),
    );
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
            child:
                CyberImeLayoutPreview(profile: CyberImeRegionalProfile.qwerty),
          ),
        ),
      ),
    );

    expect(find.byType(CyberImeKeyboardBackdrop), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(CyberButton), findsWidgets);
  });

  testWidgets('keyboard backdrop uses followLayout when capture scope exists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CyberBlurBackdropScope(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CyberBlurBackdropTarget(
                  child: ColoredBox(color: Colors.teal),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 300,
                child: CyberImeKeyboardBackdrop(),
              ),
            ],
          ),
        ),
      ),
    );

    final blur = tester.widget<CyberBackdropBlur>(
      find.byType(CyberBackdropBlur),
    );
    expect(blur.sampleMode, CyberBlurSampleMode.followLayout);
    expect(blur.backdropScope, isNotNull);
    expect(blur.captureTarget, CyberBlurCaptureTarget.currentPage);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
      'CyberImeLayoutPreview shows soft QWERTY without typewriter chrome',
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
    for (final character in ['1', '@', '€', '*', '?']) {
      expect(find.text(character), findsWidgets);
    }
    expect(find.text('Ctrl'), findsNothing);
  });

  testWidgets('AZERTY panel and preview show FR second-function faces',
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

    for (final character in ['1', '€', '@', '*']) {
      expect(find.text(character), findsWidgets);
    }

    await tester.tap(find.text('123'));
    await tester.pump();
    expect(find.text('#+='), findsOneWidget);
    expect(find.text(r'$'), findsOneWidget);

    await tester.tap(find.text('#+='));
    await tester.pump();
    expect(find.text('123'), findsWidgets);
    expect(find.text('€'), findsOneWidget);
    expect(find.text('['), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CyberImeLayoutPreview(profile: CyberImeRegionalProfile.azerty),
        ),
      ),
    );

    for (final character in ['1', '€', '@', '*']) {
      expect(find.text(character), findsWidgets);
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
    expect(find.text('Software Keyboard Layout Preview'), findsOneWidget);
    expect(find.text('q'), findsWidgets);
    await tester.tap(find.text('QWERTZ'));
    await tester.pumpAndSettle();
    expect(selected, CyberImeRegionalProfile.qwertz);
    expect(find.text('长按可输入重音字符'), findsOneWidget);
    expect(find.text('Ctrl'), findsNothing);
  });

  testWidgets(
      'CyberImeLayoutChooser can render selector without nested preview',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberImeLayoutChooser(
            selected: CyberImeRegionalProfile.qwerty,
            showPreview: false,
            showFootnote: false,
            showDisplayName: false,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    // Segment labels remain; display-name under Segment is hidden.
    expect(find.text('QWERTY'), findsOneWidget);
    expect(find.text('Software Keyboard Layout Preview'), findsNothing);
    expect(find.byType(CyberImeLayoutPreview), findsNothing);
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

  testWidgets('CyberImeTextField uses TextInputType.none', (tester) async {
    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(false),
    );
    addTearDown(() => CyberImePhysicalKeyboard.register(null));

    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyberImeTextField(
            fieldType: CyberImeFieldType.text,
            controller: ctrl,
          ),
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.none);
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

  testWidgets('Space short press inserts space', (tester) async {
    final ctrl = TextEditingController(text: 'ab');
    ctrl.selection = const TextSelection.collapsed(offset: 2);
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

    await tester.tap(find.text('space'));
    await tester.pump();
    expect(ctrl.text, 'ab ');
    expect(ctrl.selection.baseOffset, 3);
  });

  testWidgets('Space long-press without drag does not insert', (tester) async {
    final ctrl = TextEditingController(text: 'ab');
    ctrl.selection = const TextSelection.collapsed(offset: 1);
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

    final spaceFinder = find.byWidgetPredicate(
      (w) => w is CyberImeKeyCap && w.keyDef.id == CyberImeKeyId.space,
    );
    final rect = tester.getRect(spaceFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.text('← · →'), findsOneWidget);
    await gesture.up();
    await tester.pump();

    expect(ctrl.text, 'ab');
    expect(ctrl.selection.baseOffset, 1);
    expect(find.text('space'), findsOneWidget);
  });

  testWidgets('Space trackpad emits Start/Move/End lifecycle', (tester) async {
    final ctrl = TextEditingController(text: 'abcdef');
    ctrl.selection = const TextSelection.collapsed(offset: 3);
    final kb = CyberImeKeyboardController(
      fieldType: CyberImeFieldType.text,
      commit: CyberImeControllerCommit(ctrl),
    );
    addTearDown(kb.dispose);

    var starts = 0;
    var ends = 0;
    final moves = <int>[];
    kb.onSpaceTrackpadStart = () => starts++;
    kb.onSpaceTrackpadCursorMove = moves.add;
    kb.onSpaceTrackpadEnd = () => ends++;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CyberImeKeyboardPanel(controller: kb)),
      ),
    );

    final spaceFinder = find.byWidgetPredicate(
      (w) => w is CyberImeKeyCap && w.keyDef.id == CyberImeKeyId.space,
    );
    final rect = tester.getRect(spaceFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(starts, 1);
    expect(ends, 0);

    await gesture.moveBy(const Offset(-cyberImeSpaceCursorStepPx * 2, 0));
    await tester.pump();
    expect(moves, isNotEmpty);
    expect(moves.reduce((a, b) => a + b), -2);
    expect(ctrl.selection.baseOffset, 1);

    await gesture.up();
    await tester.pump();
    expect(ends, 1);
    expect(starts, 1);
  });

  testWidgets('Space long-press drag moves caret by steps', (tester) async {
    final ctrl = TextEditingController(text: 'abcdef');
    ctrl.selection = const TextSelection.collapsed(offset: 3);
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

    final spaceFinder = find.byWidgetPredicate(
      (w) => w is CyberImeKeyCap && w.keyDef.id == CyberImeKeyId.space,
    );
    final rect = tester.getRect(spaceFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));

    // Two caret steps left (2 * 14px).
    await gesture.moveBy(const Offset(-cyberImeSpaceCursorStepPx * 2, 0));
    await tester.pump();
    expect(ctrl.text, 'abcdef');
    expect(ctrl.selection.baseOffset, 1);

    await gesture.moveBy(const Offset(cyberImeSpaceCursorStepPx * 3, 0));
    await tester.pump();
    expect(ctrl.selection.baseOffset, 4);

    await gesture.up();
    await tester.pump();
    expect(ctrl.text, 'abcdef');
  });

  testWidgets('Space trackpad forces solid caret on CyberImeTextField',
      (tester) async {
    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(false),
    );
    addTearDown(() => CyberImePhysicalKeyboard.register(null));

    final ctrl = TextEditingController(text: 'abcdef');
    ctrl.selection = const TextSelection.collapsed(offset: 3);
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

    expect(find.byType(CyberImeKeyboardPanel), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).showCursor, isFalse);
    expect(
      tester.widget<CyberImeTrackpadCaretHost>(
        find.byType(CyberImeTrackpadCaretHost),
      ).active,
      isTrue,
    );

    final spaceFinder = find.byWidgetPredicate(
      (w) => w is CyberImeKeyCap && w.keyDef.id == CyberImeKeyId.space,
    );
    final rect = tester.getRect(spaceFinder);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).showCursor, isFalse);
    expect(
      tester.widget<CyberImeTrackpadCaretHost>(
        find.byType(CyberImeTrackpadCaretHost),
      ).active,
      isTrue,
    );

    await gesture.moveBy(const Offset(-cyberImeSpaceCursorStepPx * 2, 0));
    await tester.pump();
    expect(ctrl.selection.baseOffset, 1);
    // Caret chrome stays forced-visible for the whole drag, not only on up.
    expect(tester.widget<TextField>(find.byType(TextField)).showCursor, isFalse);
    expect(
      tester.widget<CyberImeTrackpadCaretHost>(
        find.byType(CyberImeTrackpadCaretHost),
      ).active,
      isTrue,
    );

    await gesture.up();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).showCursor, isFalse);
    expect(
      tester.widget<CyberImeTrackpadCaretHost>(
        find.byType(CyberImeTrackpadCaretHost),
      ).active,
      isTrue,
    );
  });
}
