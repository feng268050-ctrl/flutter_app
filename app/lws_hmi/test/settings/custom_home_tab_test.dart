import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';

Future<void> _holdThenDrag(
  WidgetTester tester,
  Finder card,
  Offset delta,
) async {
  final gesture = await tester.startGesture(tester.getCenter(card));
  await tester.pump(CustomHomeTab.dragHoldDuration);
  await tester.pump(CustomHomeTab.dragExpandDuration);
  await tester.pump();
  await gesture.moveBy(delta);
  await tester.pump();
  await gesture.up();
}

Widget _customHomeApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: ThemeData(
      extensions: const <ThemeExtension<dynamic>>[HmiTypography()],
    ),
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
        ),
        child: child!,
      );
    },
    home: home,
  );
}

void main() {
  testWidgets('dragging a candidate onto a selected slot swaps the cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _customHomeApp(
        home: Scaffold(
          body: CustomHomeTab(
            store: CustomHomeLayoutStore(
              preferencePath: '/tmp/custom-home-layout-drag-test.json',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Selected 4/4'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('custom-home-selected-wireConsumption')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-home-candidate-cutRatio')),
      findsOneWidget,
    );

    final from = tester.getCenter(
      find.byKey(const ValueKey('custom-home-card-cutRatio')),
    );
    final to = tester.getCenter(
      find.byKey(const ValueKey('custom-home-card-wireConsumption')),
    );
    await _holdThenDrag(
      tester,
      find.byKey(const ValueKey('custom-home-card-cutRatio')),
      to - from,
    );
    await tester.pumpAndSettle();

    // Insert-reorder: candidate enters the Home row; one prior Home card drops
    // into the candidate pool.
    expect(
      find.byKey(const ValueKey('custom-home-selected-cutRatio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-home-candidate-cutRatio')),
      findsNothing,
    );
    expect(find.text('Selected 4/4'), findsOneWidget);
  });

  testWidgets('quick drag without hold does not reorder cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _customHomeApp(
        home: Scaffold(
          body: CustomHomeTab(
            store: CustomHomeLayoutStore(
              preferencePath: '/tmp/custom-home-layout-slop-test.json',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final from = tester.getCenter(
      find.byKey(const ValueKey('custom-home-card-cutRatio')),
    );
    final to = tester.getCenter(
      find.byKey(const ValueKey('custom-home-card-wireConsumption')),
    );
    await tester.drag(
      find.byKey(const ValueKey('custom-home-card-cutRatio')),
      to - from,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('custom-home-candidate-cutRatio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('custom-home-selected-cutRatio')),
      findsNothing,
    );
  });

  testWidgets('dragging reorders within the selected row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _customHomeApp(
        home: Scaffold(
          body: CustomHomeTab(
            store: CustomHomeLayoutStore(
              preferencePath: '/tmp/custom-home-layout-reorder-test.json',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final from = tester.getCenter(
      find.byKey(const ValueKey('custom-home-card-wireConsumption')),
    );
    final to = tester.getCenter(
      find.byKey(const ValueKey('custom-home-card-laserOnDuration')),
    );
    await _holdThenDrag(
      tester,
      find.byKey(const ValueKey('custom-home-card-wireConsumption')),
      to - from,
    );
    await tester.pumpAndSettle();

    // Slot badges follow selected order; wireConsumption should leave slot 1.
    final wireCard = find.byKey(
      const ValueKey('custom-home-card-wireConsumption'),
    );
    expect(
      find.descendant(of: wireCard, matching: find.text('1')),
      findsNothing,
    );
    expect(
      find.descendant(of: wireCard, matching: find.text('2')),
      findsOneWidget,
    );
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

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-home-save-success-ok')),
        findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
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
