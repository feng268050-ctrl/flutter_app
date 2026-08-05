import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  testWidgets('SettingsScaffold uses ProductPageStatusBar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SettingsScaffold(
          title: 'Wi‑Fi',
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ProductPageStatusBar), findsOneWidget);
    expect(find.byType(SettingsStatusBarHairline), findsOneWidget);
    expect(find.byType(SettingsBlurredPageShell), findsOneWidget);
    expect(find.text('Wi‑Fi'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-bar-clock')), findsOneWidget);

    // Match Quick / Engineer WorkModeStatusBarDimens.chromeLabelFontSize.
    final clock = tester.widget<Text>(
      find.byKey(const ValueKey('cyber-status-bar-clock')),
    );
    expect(clock.style?.fontSize, 20);
  });

  testWidgets('nested SettingsScaffold skips live page ImageFiltered',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      buildAppSlideRoute<void>(
                        builder: (_) => const SettingsScaffold(
                          title: 'Wi‑Fi',
                          body: SizedBox.shrink(),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump(); // start route
    await tester.pump(const Duration(milliseconds: 400)); // finish Cupertino slide

    final shell = tester.widget<SettingsBlurredPageShell>(
      find.byType(SettingsBlurredPageShell),
    );
    // Nested: no live ImageFiltered — shell default bakes a static σ30 plate.
    expect(shell.livePageBlur, isFalse);
    expect(find.byType(ImageFiltered), findsNothing);
  });
}
