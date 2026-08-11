import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ui_scale 1.0 leaves MediaQuery size unchanged', (tester) async {
    late Size innerSize;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1280, 800),
          devicePixelRatio: 1.0,
        ),
        child: Builder(
          builder: (context) {
            return matchEmbedderDensity(
              context,
              Builder(
                builder: (context) {
                  innerSize = MediaQuery.sizeOf(context);
                  return const SizedBox.shrink();
                },
              ),
              uiScale: 1.0,
            );
          },
        ),
      ),
    );
    expect(innerSize, const Size(1280, 800));
  });

  testWidgets('ui_scale 1.13 shrinks logical size by the multiplier',
      (tester) async {
    late Size innerSize;
    late double innerDpr;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1280, 800),
          devicePixelRatio: 1.0,
        ),
        child: Builder(
          builder: (context) {
            return matchEmbedderDensity(
              context,
              Builder(
                builder: (context) {
                  innerSize = MediaQuery.sizeOf(context);
                  innerDpr = MediaQuery.devicePixelRatioOf(context);
                  return const SizedBox.shrink();
                },
              ),
              uiScale: 1.13,
            );
          },
        ),
      ),
    );
    expect(innerSize.width, closeTo(1280 / 1.13, 0.01));
    expect(innerSize.height, closeTo(800 / 1.13, 0.01));
    expect(innerDpr, closeTo(1.13, 0.01));
  });
}
