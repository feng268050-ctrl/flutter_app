import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';

void main() {
  tearDown(ProcessModeToast.resetForTest);

  testWidgets('shows bottom-center light frost toast via in-page layer',
      (tester) async {
    addTearDown(ProcessModeToast.resetForTest);
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessModeToastLayer(
          child: Builder(
            builder: (context) {
              return Scaffold(
                backgroundColor: const Color(0xFFF46E01),
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        ProcessModeToast.show(context, 'Manual gas on'),
                    child: const Text('Go'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(); // capture post-frame

    final toast = find.byKey(const ValueKey('process-mode-toast'));
    expect(toast, findsOneWidget);
    final text = tester.widget<Text>(toast);
    expect(text.data, 'Manual gas on');
    expect(text.style?.fontSize, ProcessModeToast.textSize);
    expect(text.style?.color, ProcessModeToast.textColor);

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: toast, matching: find.byType(Positioned)).first,
    );
    expect(positioned.bottom, ProcessModeToast.bottomInset);
    ProcessModeToast.resetForTest();
    await tester.pump();
  });

  testWidgets('replaces previous toast with a new message', (tester) async {
    addTearDown(ProcessModeToast.resetForTest);
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessModeToastLayer(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => ProcessModeToast.show(context, 'First'),
                      child: const Text('Show first'),
                    ),
                    ElevatedButton(
                      onPressed: () => ProcessModeToast.show(context, 'Second'),
                      child: const Text('Show second'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show first'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('process-mode-toast'))).data,
      'First',
    );

    await tester.tap(find.text('Show second'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('process-mode-toast'))).data,
      'Second',
    );
    ProcessModeToast.resetForTest();
    await tester.pump();
  });

  testWidgets('auto-dismisses after short duration', (tester) async {
    addTearDown(ProcessModeToast.resetForTest);
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessModeToastLayer(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => ProcessModeToast.show(context, 'Bye'),
                  child: const Text('Go'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(find.byKey(const ValueKey('process-mode-toast')), findsOneWidget);

    await tester.pump(ProcessModeToast.shortDuration);
    await tester.pump();
    expect(find.byKey(const ValueKey('process-mode-toast')), findsNothing);
  });
}
