import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_coordinator.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';
import 'package:lws_hmi/features/safety_tips/presentation/safety_tips_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

Widget _safetyTipsTestApp({required Widget home}) {
  return MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en', 'US'),
    home: home,
    onGenerateRoute: (settings) {
      if (settings.name == AppRoutes.productDisclaimer) {
        return buildAppSlideRoute<void>(
          settings: settings,
          builder: (_) => const ProductDisclaimerPage(),
        );
      }
      return null;
    },
  );
}

void main() {
  tearDown(SafetyTipsCoordinator.resetForTest);

  testWidgets('Safety Tips Agree dismisses; link opens Product Disclaimer route',
      (tester) async {
    await tester.pumpWidget(
      _safetyTipsTestApp(
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

    expect(find.text('Safety Tips'), findsOneWidget);
    expect(find.textContaining('Keep bystanders'), findsOneWidget);

    // Product Disclaimer is a named route (slide), not a nested dialog.
    await tester.tap(find.byKey(const ValueKey('safety-tips-disclaimer-link')));
    await tester.pumpAndSettle();
    expect(find.text('Product Disclaimer'), findsOneWidget);
    expect(find.textContaining('Dear User:'), findsOneWidget);
    expect(
      find.byType(ProductDisclaimerPage),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('product-disclaimer-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Product Disclaimer'), findsNothing);
    expect(find.byType(ProductDisclaimerPage), findsNothing);
    expect(find.text('Safety Tips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Safety Tips'), findsNothing);
  });

  testWidgets('Agree stays disabled while unchecked', (tester) async {
    await tester.pumpWidget(
      _safetyTipsTestApp(
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
    expect(find.text('Safety Tips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-cb')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Safety Tips'), findsNothing);
  });

  testWidgets('EN Safety Tips Agree uses HmiButton small; no overflow at panel size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _safetyTipsTestApp(
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

    final agree = find.byKey(const ValueKey('safety-tips-agree-btn'));
    expect(agree, findsOneWidget);
    expect(tester.widget(agree), isA<HmiButton>());
    expect(tester.getSize(agree).height, 44);
    expect(tester.getSize(agree).width, 163);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Safety Tips'), findsNothing);
    expect(SafetyTipsGate.hasAcceptedThisProcess, isFalse);
  });
}
