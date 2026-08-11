import 'package:cyber_settings_ui/cyber_settings_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SettingsWallpaperPicker enables apply after carousel swipe',
      (tester) async {
    const options = [
      SettingsWallpaperOption(
        id: 'a',
        label: 'Default',
        imagePath: '',
      ),
      SettingsWallpaperOption(
        id: 'b',
        label: 'Alt',
        imagePath: '',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [SettingsTypography()],
        ),
        home: Scaffold(
          body: SettingsWallpaperPicker(
            options: options,
            appliedId: 'a',
            applyLabel: 'Apply',
            onApply: (_) async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final applyButton = find.byType(CyberButton);
    expect(tester.widget<CyberButton>(applyButton).onPressed, isNull);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Alt'), findsOneWidget);
    expect(tester.widget<CyberButton>(applyButton).onPressed, isNotNull);
  });
}
