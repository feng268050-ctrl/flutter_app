import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/custom_home_tab.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/custom_home_save_success_dialog.dart';

void main() {
  testWidgets('pointer drag immediately reorders custom-home cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
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

    final wire = find.byKey(const ValueKey('custom-home-card-wireConsumption'));
    final laser =
        find.byKey(const ValueKey('custom-home-card-laserOnDuration'));
    final wireStart = tester.getTopLeft(wire);
    final laserStart = tester.getCenter(laser);

    final gesture = await tester.startGesture(tester.getCenter(wire));
    await gesture.moveTo(laserStart);
    await tester.pump(const Duration(milliseconds: 240));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 240));

    expect(tester.getTopLeft(wire), isNot(wireStart));
  });

  testWidgets('Custom Home success tip auto-dismisses after 1.5 seconds',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
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
    expect(find.text('Please try again'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('custom-home-save-success-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Save Failed'), findsNothing);
  });
}
