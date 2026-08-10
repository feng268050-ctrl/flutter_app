import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/call_back_home_button.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  testWidgets('SettingsScaffold uses Back + page title + trailing clock',
      (tester) async {
    // Push so canPop is true and CallBackHomeButton is shown.
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProductPageStatusBar), findsOneWidget);
    expect(find.byType(SettingsStatusBarHairline), findsOneWidget);
    expect(find.byType(SettingsBlurredPageShell), findsOneWidget);

    final backBtn = tester.widget<CallBackHomeButton>(
      find.byType(CallBackHomeButton),
    );
    expect(backBtn.label, 'Back');
    expect(backBtn.showEdgeAccent, isFalse);
    expect(find.text('Back'), findsOneWidget);
    // Page title is in the AppBar title slot (not the leading label).
    expect(find.text('Wi‑Fi'), findsOneWidget);

    expect(find.byKey(const ValueKey('cyber-status-bar-clock')), findsOneWidget);

    final clock = tester.widget<Text>(
      find.byKey(const ValueKey('cyber-status-bar-clock')),
    );
    expect(clock.style?.fontSize, CallBackHomeButton.labelFontSize);
    expect(clock.data, isNotNull);
    expect(clock.data!.split(' ').length, greaterThanOrEqualTo(2));
    expect(clock.data, contains(':'));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final shell = tester.widget<SettingsBlurredPageShell>(
      find.byType(SettingsBlurredPageShell),
    );
    // Nested: no live ImageFiltered — shell default bakes a static σ30 plate.
    expect(shell.livePageBlur, isFalse);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets(
    'root SettingsScaffold keeps disabled Back (host upgrade stack clear)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SettingsScaffold(
            title: 'System Upgrade',
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CallBackHomeButton), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      final label = tester.widget<Text>(find.text('Back'));
      expect(label.style?.color, WorkModeStatusBarDimens.backLabelDisabled);

      // Cannot pop — tap must not navigate away.
      await tester.tap(find.byKey(const ValueKey('call-back-home-button')));
      await tester.pump();
      expect(find.text('System Upgrade'), findsOneWidget);
    },
  );
}
