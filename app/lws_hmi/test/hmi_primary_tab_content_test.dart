import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_tab_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_primary_tab_content.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [HmiTypography()],
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('icon–label gap stays 8 for short and long labels',
      (tester) async {
    Future<double> gapFor(String label) async {
      await tester.pumpWidget(
        wrap(
          HmiPrimaryTabContent(
            key: ValueKey(label),
            icon: const Icon(Icons.settings, size: HmiTabMetrics.iconSize),
            label: label,
            color: Colors.white,
            selected: false,
          ),
        ),
      );
      await tester.pump();
      final iconBox = tester.getRect(find.byIcon(Icons.settings));
      final textBox = tester.getRect(find.text(label));
      return textBox.left - iconBox.right;
    }

    expect(await gapFor('General'), HmiTabMetrics.iconLabelGap);
    expect(await gapFor('Custom Home'), HmiTabMetrics.iconLabelGap);
    expect(await gapFor('Advanced'), HmiTabMetrics.iconLabelGap);
  });

  test('metrics match primary tab ladder', () {
    expect(HmiTabMetrics.iconSize, 28);
    expect(HmiTabMetrics.labelFontSize, 24);
    expect(HmiTabMetrics.iconLabelGap, 8);
    expect(HmiTabMetrics.labelWeight, FontWeight.w500);
    expect(HmiTabMetrics.selectedLabelWeight, FontWeight.w600);
  });
}
