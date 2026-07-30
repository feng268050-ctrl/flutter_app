import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';

void main() {
  testWidgets('SettingsScaffold uses ProductPageStatusBar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScaffold(
          title: 'Wi‑Fi',
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ProductPageStatusBar), findsOneWidget);
    expect(find.text('Wi‑Fi'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-bar-clock')), findsOneWidget);

    // Match Quick / Engineer WorkModeStatusBarDimens.chromeLabelFontSize.
    final clock = tester.widget<Text>(
      find.byKey(const ValueKey('cyber-status-bar-clock')),
    );
    expect(clock.style?.fontSize, 20);
  });
}
