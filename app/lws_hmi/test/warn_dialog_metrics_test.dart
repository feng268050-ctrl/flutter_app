import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_dialog_body.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(Widget child, {Size size = const Size(1280, 800)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    );
  }

  testWidgets('warn dialogs share unified 725×≥480 card size', (tester) async {
    const titles = [
      'Camera Communication Alarm',
      'Gas Pressure Low',
      'E-Stop',
    ];
    final sizes = <Size>[];

    for (final title in titles) {
      await tester.pumpWidget(
        harness(
          WarnDialogBody(
            title: title,
            body: 'Power off, wait 10 seconds, then power on again.',
            onConfirm: () {},
          ),
        ),
      );
      await tester.pump();

      final box = tester.renderObject<RenderBox>(find.byType(WarnDialogBody));
      sizes.add(box.size);
    }

    for (final size in sizes) {
      expect(size.width, WarnDialogMetrics.minCardWidth);
      expect(size.height, greaterThanOrEqualTo(WarnDialogMetrics.minCardHeight));
      expect(size.height, lessThanOrEqualTo(WarnDialogMetrics.maxCardHeightDimen));
    }
    expect(sizes[0], sizes[1]);
    expect(sizes[1], sizes[2]);
  });

  testWidgets('warn card shrinks on narrow screens', (tester) async {
    await tester.pumpWidget(
      harness(
        size: const Size(640, 800),
        WarnDialogBody(
          title: 'Camera Communication Alarm',
          body: 'Short body.',
          onConfirm: () {},
        ),
      ),
    );
    await tester.pump();

    final box = tester.renderObject<RenderBox>(find.byType(WarnDialogBody));
    expect(box.size.width, 640 * WarnDialogMetrics.maxWidthFraction);
  });

  testWidgets('content is top-aligned — no large empty band above icon',
      (tester) async {
    await tester.pumpWidget(
      harness(
        WarnDialogBody(
          title: 'Camera Communication Alarm',
          body:
              'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.',
          onConfirm: () {},
        ),
      ),
    );
    await tester.pump();

    final card = tester.getRect(find.byType(WarnDialogBody));
    final icon = tester.getRect(find.byType(Image));
    final confirm = tester.getRect(find.text('Confirm'));
    // Measure the scroll viewport, not the full (possibly taller) text child.
    final bodyViewport = tester.getRect(find.byType(SingleChildScrollView));

    // Icon sits near the top inset (~36), not mid-card.
    expect(icon.top - card.top, lessThan(80));

    // Confirm stays below the body viewport — no overlap.
    expect(confirm.top, greaterThan(bodyViewport.bottom + 8));
  });

  testWidgets('long title fits one line fully inside content band',
      (tester) async {
    const title = 'Camera Communication Alarm';
    await tester.pumpWidget(
      harness(
        WarnDialogBody(
          title: title,
          body: 'Power off, wait 10 seconds, then power on again.',
          onConfirm: () {},
        ),
      ),
    );
    await tester.pump();

    final titleFinder = find.text(title);
    expect(titleFinder, findsOneWidget);

    final text = tester.widget<Text>(titleFinder);
    expect(text.maxLines, 1);

    final cardW = WarnDialogMetrics.minCardWidth;
    final titleMax = WarnDialogMetrics.titleMaxWidth(cardW, 1.0);
    final painter = TextPainter(
      text: TextSpan(text: title, style: text.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(titleMax + 0.5));
  });
}
