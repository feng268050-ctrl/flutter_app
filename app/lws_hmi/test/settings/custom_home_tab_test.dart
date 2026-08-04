import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';

void main() {
  testWidgets('cancel then add moves a card between Custom Home zones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CustomHomeTab(
            store: CustomHomeLayoutStore(
              preferencePath: '/tmp/custom-home-layout-test.json',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Selected 4/4'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('custom-home-remove-wireConsumption')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected 3/4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('custom-home-save')));
    await tester.pump();
    expect(find.text('Please Select 4 Cards'), findsOneWidget);
    ProcessModeToast.resetForTest();

    await tester.tap(
      find.byKey(const ValueKey('custom-home-card-wireConsumption')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected 4/4'), findsOneWidget);
  });

  testWidgets('full Custom Home selection enters replace mode then swaps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(ProcessModeToast.resetForTest);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: CustomHomeTab(
            store: CustomHomeLayoutStore(
              preferencePath: '/tmp/custom-home-layout-replace-test.json',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('custom-home-card-cutRatio')),
    );
    await tester.pump();
    expect(find.text('Please Select A Card To Replace'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-home-card-cutRatio')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('custom-home-card-cleanRatio')),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-home-card-cutRatio')),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-home-card-cleanRatio')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('custom-home-card-wireConsumption')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected 4/4'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-home-remove-cleanRatio')),
        findsOneWidget);
    ProcessModeToast.resetForTest();
  });

  testWidgets('Custom Home success tip auto-dismisses after 1.5 seconds',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('show-custom-home-save-tip'),
              onPressed: () => showCustomHomeSaveSuccessDialog(context),
              child: const Text('Show save tip'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('show-custom-home-save-tip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('Save Succeeded'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-home-save-success-ok')),
        findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Save Succeeded'), findsNothing);
  });

  testWidgets('Custom Home failure tip uses failure copy and dismisses',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCustomHomeSaveFailureDialog(context),
              child: const Text('Show failure tip'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show failure tip'));
    await tester.pumpAndSettle();

    expect(find.text('Save Failed'), findsOneWidget);
    expect(find.text('Please Try Again'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('custom-home-save-success-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Save Failed'), findsNothing);
  });
}
