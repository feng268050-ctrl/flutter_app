import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HmiButtonMetrics 100% ladder matches baseline heights and sizes', () {
    const typography = HmiTypography();
    expect(HmiButtonMetrics.forSize(HmiButtonSize.mini, typography).height, 36);
    expect(HmiButtonMetrics.forSize(HmiButtonSize.small, typography).height, 44);
    expect(
        HmiButtonMetrics.forSize(HmiButtonSize.medium, typography).height, 52);
    expect(HmiButtonMetrics.forSize(HmiButtonSize.large, typography).height, 60);
    expect(HmiButtonMetrics.forSize(HmiButtonSize.hero, typography).height, 72);

    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.mini, typography).textStyle.fontSize,
      14,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.small, typography)
          .textStyle
          .fontSize,
      16,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.medium, typography)
          .textStyle
          .fontSize,
      18,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.large, typography)
          .textStyle
          .fontSize,
      20,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.hero, typography).textStyle.fontSize,
      24,
    );
  });

  testWidgets('HmiButton applies metrics height for medium', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: HmiButton(
              key: const ValueKey('hmi-btn'),
              label: 'Confirm',
              size: HmiButtonSize.medium,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('hmi-btn'))).height, 52);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
