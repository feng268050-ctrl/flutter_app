import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('WarnChromeStyle', () {
    test('info flag', () {
      expect(WarnChromeStyle.warn.isInfo, isFalse);
      expect(WarnChromeStyle.info.isInfo, isTrue);
    });
  });

  group('WarnDialogBody', () {
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
        expect(
          size.height,
          lessThanOrEqualTo(WarnDialogMetrics.maxCardHeightDimen),
        );
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
      final bodyViewport = tester.getRect(find.byType(SingleChildScrollView));

      expect(icon.top - card.top, lessThan(80));
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

    testWidgets('body font size does not exceed fitted title', (tester) async {
      const title = 'Camera Communication Alarm';
      const body =
          'Power off, wait 10 seconds, then power on again. If the alarm remains, contact LaserCyber support.';
      await tester.pumpWidget(
        harness(
          WarnDialogBody(
            title: title,
            body: body,
            onConfirm: () {},
          ),
        ),
      );
      await tester.pump();

      final titleSize = tester.widget<Text>(find.text(title)).style!.fontSize!;
      final bodySize = tester.widget<Text>(find.text(body)).style!.fontSize!;
      expect(titleSize, lessThan(WarnDialogMetrics.titleSize));
      expect(bodySize, lessThanOrEqualTo(titleSize));
    });

    testWidgets('INFO chrome uses black title', (tester) async {
      await tester.pumpWidget(
        harness(
          WarnDialogBody(
            title: 'Camera Communication Alarm',
            body: 'Body',
            infoStyle: true,
            onConfirm: () {},
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Camera Communication Alarm'));
      expect(title.style?.color, WarnDialogBody.titleBlack);
    });

    testWidgets('WARN chrome uses red title', (tester) async {
      await tester.pumpWidget(
        harness(
          WarnDialogBody(
            title: 'Gun Communication Alarm',
            body: 'Body',
            onConfirm: () {},
          ),
        ),
      );
      await tester.pump();

      final title = tester.widget<Text>(find.text('Gun Communication Alarm'));
      expect(title.style?.color, WarnDialogBody.titleRed);
      expect(find.byType(CyberFrostDivider), findsNWidgets(2));
    });

    testWidgets('package warn/info icons resolve', (tester) async {
      await tester.pumpWidget(
        harness(
          WarnDialogBody(
            title: 'T',
            body: 'B',
            onConfirm: () {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        harness(
          WarnDialogBody(
            title: 'T',
            body: 'B',
            chromeStyle: WarnChromeStyle.info,
            onConfirm: () {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  test('WarnDialogMetrics ladder sizes stay on FrostUI 100% scale', () {
    expect(WarnDialogMetrics.titleSize, 52);
    expect(WarnDialogMetrics.bodySize, 36);
    expect(WarnDialogMetrics.confirmLabelSize, 24);
    expect(WarnDialogMetrics.minTitleSize, 18);
  });

  test('WarnFrostShell LIGHT glass tokens match lws-ui work-status colors', () {
    expect(WarnFrostShell.blurSigma, 25);
    expect(
      WarnFrostShell.backdropGradient.colors,
      const [
        CyberColors.lightWarnBackdropEdge,
        CyberColors.lightWarnBackdropBlend,
        CyberColors.lightWarnBackdropCenter,
        CyberColors.lightWarnBackdropBlend,
        CyberColors.lightWarnBackdropEdge,
      ],
    );
    expect(CyberColors.lightWarnBackdropEdge, const Color(0xB8FFEFD0));
    expect(CyberColors.lightWarnBackdropCenter, const Color(0xBFFFFFFF));
    expect(CyberColors.lightShellFrostEdge, const Color(0x28FFFFFF));
    expect(CyberColors.lightShellFrostCenter, const Color(0x1FFFFFFF));
    expect(CyberColors.creamDialogRim, const Color(0xFF000000));
    expect(
      const CyberPanelBorder(tone: CyberTone.light)
          .creamDialogRimOutline
          .resolvedUniformColor,
      CyberColors.creamDialogRim,
    );
    // No opaque cream plate — wash is translucent warm-yellow gradient.
    expect(WarnFrostShell.backdropGradient.colors.every((c) => c.alpha < 0xFF),
        isTrue);
  });
}
