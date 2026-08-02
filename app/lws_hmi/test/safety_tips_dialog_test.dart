import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_coordinator.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';
import 'package:lws_hmi/features/safety_tips/presentation/safety_tips_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  tearDown(SafetyTipsCoordinator.resetForTest);

  testWidgets('Safety Tips Agree dismisses; link opens Product Disclaimer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en', 'US'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-safety-tips'),
                  onPressed: () {
                    showSafetyTipsDialog(context: context);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-safety-tips')));
    await tester.pumpAndSettle();

    expect(find.text('Safety Operation Tips'), findsOneWidget);
    expect(find.textContaining('Ensure there are no other personnel'),
        findsOneWidget);

    // Open nested Product Disclaimer via blue link.
    await tester.tap(find.byKey(const ValueKey('safety-tips-disclaimer-link')));
    await tester.pumpAndSettle();
    expect(find.text('Product Disclaimer'), findsOneWidget);
    expect(find.textContaining('Dear User:'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('product-disclaimer-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Product Disclaimer'), findsNothing);
    expect(find.text('Safety Operation Tips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Safety Operation Tips'), findsNothing);
  });

  testWidgets('Agree stays disabled while unchecked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en', 'US'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSafetyTipsDialog(context: context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-cb')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-btn')));
    await tester.pumpAndSettle();
    // Still showing — Agree ignored while unchecked.
    expect(find.text('Safety Operation Tips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-cb')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Safety Operation Tips'), findsNothing);
  });

  testWidgets('coordinator skip gate completes without dialog', (tester) async {
    SafetyTipsCoordinator.resetForTest(skipGate: true);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  SafetyTipsCoordinator.showWhenHomeEntered(
                    context: context,
                    onComplete: () => completed = true,
                  );
                },
                child: const Text('Go'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(completed, isTrue);
    expect(find.text('Safety Operation Tips'), findsNothing);
    expect(SafetyTipsGate.hasAcceptedThisProcess, isFalse);
  });
}
