import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_mode_entry_tips_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

void main() {
  testWidgets('engineer tip shows full title and body (no clip)', (tester) async {
    // Prefer view.physicalSize — setSurfaceSize alone can leave MediaQuery at
    // the default 800×600 in this Flutter pin, which would keep cardH at 600.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEngineerModeEntryTipsDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('engineer-mode-entry-tips')),
      findsOneWidget,
    );
    // Full title — not ellipsized ("Engineer Mode No…").
    expect(find.text('Engineer Mode Notice'), findsOneWidget);
    // Body is word-boundary wrapped (one Text per English token).
    expect(find.text('adjustments.'), findsOneWidget);
    expect(find.byType(CyberCheckbox), findsOneWidget);
    final checkbox = tester.widget<CyberCheckbox>(find.byType(CyberCheckbox));
    expect(checkbox.size, CyberDimens.checkboxLargeSize);
    expect(find.byType(TipFrostDivider), findsNWidgets(2));

    final card = tester.getSize(
      find
          .ancestor(
            of: find.byKey(const ValueKey('engineer-mode-entry-tips')),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    // Title-based width (≥700, ≤95% screen) so 53sp title fits.
    expect(card.width, greaterThanOrEqualTo(700));
    expect(card.width, lessThanOrEqualTo(1280 * 0.95));
    // cardH = (800 + 600) / 2 → 700; margins ~50 each (half of former ~100).
    expect(card.height, moreOrLessEquals(700, epsilon: 1));
  });
}
