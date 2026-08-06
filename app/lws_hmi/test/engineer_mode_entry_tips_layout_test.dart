import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_mode_entry_tips_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  testWidgets('engineer tip shows full title and body (no clip)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(
      find.textContaining('before making fine adjustments.'),
      findsOneWidget,
    );
    expect(find.byType(CyberCheckbox), findsOneWidget);
    final checkbox = tester.widget<CyberCheckbox>(find.byType(CyberCheckbox));
    expect(checkbox.size, CyberDimens.checkboxLargeSize);

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
    expect(card.height, greaterThanOrEqualTo(480));
    expect(card.height, lessThanOrEqualTo(680));
  });
}
