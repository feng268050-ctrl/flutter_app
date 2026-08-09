import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';

void main() {
  testWidgets('navigation rows use the shared centered frame at Large', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.12)),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: SettingsNavRow(title: 'Large row'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SettingsRowFrame), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    final frame = tester.getRect(find.byType(SettingsRowFrame));
    final text = tester.getRect(find.text('Large row'));
    expect(frame.height, closeTo(SettingsDimens.rowMinHeight * 1.12, 0.1));
    expect(text.center.dy, closeTo(frame.center.dy, 0.1));
  });
}
