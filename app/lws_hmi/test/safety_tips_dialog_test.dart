import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_coordinator.dart';
import 'package:lws_hmi/features/safety_tips/application/safety_tips_gate.dart';
import 'package:lws_hmi/features/safety_tips/presentation/safety_tips_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

Widget _safetyTipsTestApp({String initialRoute = AppRoutes.safetyTips}) {
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.safetyTips:
        return buildAppPageRoute(
          settings: settings,
          child: const SafetyTipsPage(),
        );
      case AppRoutes.productDisclaimer:
        return buildAppSlideRoute<void>(
          settings: settings,
          builder: (_) => const ProductDisclaimerPage(),
        );
      case AppRoutes.home:
        return buildAppPageRoute(
          settings: settings,
          child: const Scaffold(
            body: Center(child: Text('Home')),
          ),
        );
    }
    return null;
  }

  return MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en', 'US'),
    initialRoute: initialRoute,
    onGenerateInitialRoutes: (name) =>
        generateAppInitialRoutes(name, onGenerateRoute),
    onGenerateRoute: onGenerateRoute,
  );
}

void main() {
  tearDown(SafetyTipsCoordinator.resetForTest);

  testWidgets('Safety Tips Agree replaces with Home; link opens Disclaimer',
      (tester) async {
    await tester.pumpWidget(_safetyTipsTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(SafetyTipsPage), findsOneWidget);
    expect(find.text('Safety Tips'), findsOneWidget);
    // Body is Markdown (structured lists / headings from ARB).
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('bystanders'), findsOneWidget);
    expect(SafetyTipsGate.isActive, isTrue);

    // Product Disclaimer is a named route (slide), not a nested dialog.
    await tester.tap(find.byKey(const ValueKey('safety-tips-disclaimer-link')));
    await tester.pumpAndSettle();
    expect(find.text('Product Disclaimer'), findsOneWidget);
    expect(find.textContaining('Dear User'), findsOneWidget);
    expect(find.textContaining('Safety Warning'), findsOneWidget);
    expect(find.byType(ProductDisclaimerPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('product-disclaimer-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Product Disclaimer'), findsNothing);
    expect(find.byType(ProductDisclaimerPage), findsNothing);
    expect(find.text('Safety Tips'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('safety-tips-agree-btn')));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyTipsPage), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(SafetyTipsGate.hasAcceptedThisProcess, isTrue);
    expect(SafetyTipsGate.isActive, isFalse);
  });

  testWidgets('Agree stays disabled while unchecked', (tester) async {
    await tester.pumpWidget(_safetyTipsTestApp());
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
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('EN Safety Tips Agree uses HmiButton large; no overflow at panel size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_safetyTipsTestApp());
    await tester.pumpAndSettle();

    final agree = find.byKey(const ValueKey('safety-tips-agree-btn'));
    expect(agree, findsOneWidget);
    expect(tester.widget(agree), isA<HmiButton>());
    expect(tester.getSize(agree).height, 60);
    // Matches dialog equal-action width (`width: 196` on Agree).
    expect(tester.getSize(agree).width, 196);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gate skip uses Home as initial route', (tester) async {
    SafetyTipsCoordinator.resetForTest(skipGate: true);
    expect(SafetyTipsGate.initialRoute, AppRoutes.home);

    await tester.pumpWidget(_safetyTipsTestApp(initialRoute: AppRoutes.home));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(SafetyTipsPage), findsNothing);
    expect(SafetyTipsGate.hasAcceptedThisProcess, isFalse);
  });

  testWidgets('production initialRoute is Safety Tips before accept', (tester) async {
    SafetyTipsCoordinator.resetForTest();
    expect(SafetyTipsGate.initialRoute, AppRoutes.safetyTips);
    expect(find.byType(SafetyTipsPage), findsNothing);

    await tester.pumpWidget(_safetyTipsTestApp());
    await tester.pumpAndSettle();
    expect(find.byType(SafetyTipsPage), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });
}
