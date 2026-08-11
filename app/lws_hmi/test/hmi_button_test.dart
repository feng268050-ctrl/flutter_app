import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_outline_button.dart';
import 'package:lws_hmi/ui/hmi/hmi_adaptive_icon_label.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HmiButtonMetrics 100% ladder matches baseline heights and sizes', () {
    const typography = HmiTypography();
    expect(HmiButtonMetrics.forSize(HmiButtonSize.mini, typography).height, 36);
    expect(
        HmiButtonMetrics.forSize(HmiButtonSize.small, typography).height, 44);
    expect(
        HmiButtonMetrics.forSize(HmiButtonSize.medium, typography).height, 52);
    expect(
        HmiButtonMetrics.forSize(HmiButtonSize.large, typography).height, 60);
    expect(HmiButtonMetrics.forSize(HmiButtonSize.hero, typography).height, 68);
    expect(
        HmiButtonMetrics.forSize(HmiButtonSize.jumbo, typography).height, 88);

    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.mini, typography)
          .textStyle
          .fontSize,
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
      20,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.large, typography)
          .textStyle
          .fontSize,
      24,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.hero, typography)
          .textStyle
          .fontSize,
      24,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.jumbo, typography)
          .textStyle
          .fontSize,
      32,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.jumbo, typography).minWidth,
      240,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.jumbo, typography)
          .horizontalPadding,
      36,
    );
    expect(
      HmiButtonMetrics.forSize(HmiButtonSize.jumbo, typography).iconSize,
      36,
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

  test('icon label layout selects mode from measured geometry', () {
    expect(
      HmiIconLabelLayout.modeFor(
        maxWidth: 320,
        labelWidth: 140,
        buttonHeight: 60,
        iconSize: 28,
        horizontalPadding: 20,
      ),
      HmiIconLabelLayoutMode.labelCentered,
    );
    expect(
      HmiIconLabelLayout.modeFor(
        maxWidth: 230,
        labelWidth: 140,
        buttonHeight: 60,
        iconSize: 28,
        horizontalPadding: 20,
      ),
      HmiIconLabelLayoutMode.groupedCentered,
    );
  });

  test('resolveLabelCenteredInsets nudges label and keeps equal chrome', () {
    // Short label: stays centered; L/R chrome = edge inset.
    final roomy = HmiIconLabelLayout.resolveLabelCenteredInsets(
      maxWidth: 275,
      labelWidth: 120,
      buttonHeight: 68,
      iconSize: 32,
      hasLeading: true,
      iconLabelClearance: 3,
    );
    expect(roomy.edgeInset, 18);
    expect(roomy.labelLeft, closeTo((275 - 120) / 2, 0.01));
    expect(roomy.overflows, isFalse);

    // Long label: nudge past icon + 3px; right inset stays edgeInset.
    final tight = HmiIconLabelLayout.resolveLabelCenteredInsets(
      maxWidth: 275,
      labelWidth: 220,
      buttonHeight: 68,
      iconSize: 32,
      hasLeading: true,
      iconLabelClearance: 3,
    );
    expect(tight.labelLeft, closeTo(18 + 32 + 3, 0.01));
    expect(tight.labelMaxWidth, closeTo(275 - 18 - tight.labelLeft, 0.01));
    expect(tight.overflows, isTrue);

    // Wide button: label centered; equal spacing on both sides of icon.
    final wide = HmiIconLabelLayout.resolveTextBandCenteredInsets(
      maxWidth: 320,
      labelWidth: 140,
      buttonHeight: 60,
      iconSize: 28,
      gap: 8,
    );
    expect(wide.labelLeft, closeTo((320 - 140) / 2, 0.01));
    expect(wide.iconLeft, closeTo((wide.labelLeft - 28) / 2, 0.01));
    expect(
      wide.labelLeft - wide.iconLeft - 28,
      closeTo(wide.iconLeft, 0.01),
    );
  });

  test('grouped layout reduces only the icon gap before ellipsizing text', () {
    expect(
      HmiIconLabelLayout.groupedGapFor(
        availableWidth: 202,
        labelWidth: 168,
        iconSize: 32,
        accessoryCount: 1,
      ),
      HmiIconLabelLayout.minimumIconLabelGap,
    );
    expect(
      HmiIconLabelLayout.groupedGapFor(
        availableWidth: 220,
        labelWidth: 168,
        iconSize: 32,
        accessoryCount: 1,
      ),
      HmiIconLabelLayout.iconLabelGap,
    );
  });

  test('resolveGroupedInsets keeps equal side padding and full label', () {
    // Fits at design gap: leftover split equally.
    final roomy = HmiIconLabelLayout.resolveGroupedInsets(
      maxWidth: 269,
      labelWidth: 168,
      iconSize: 32,
      accessoryCount: 1,
      preferredPadding: 18,
    );
    expect(roomy.overflows, isFalse);
    expect(roomy.gap, HmiIconLabelLayout.iconLabelGap);
    expect(roomy.padding, closeTo((269 - (168 + 32 + 8)) / 2, 0.01));

    // Needs tighter equal insets to keep full label.
    final tight = HmiIconLabelLayout.resolveGroupedInsets(
      maxWidth: 269,
      labelWidth: 220,
      iconSize: 32,
      accessoryCount: 1,
      preferredPadding: 18,
    );
    expect(tight.overflows, isFalse);
    expect(tight.padding * 2 + 220 + 32 + tight.gap, closeTo(269, 0.01));
  });

  testWidgets('forceTextBandCentered centers label with balanced icon spacing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: HmiButton(
                key: const ValueKey('balanced-hmi-button'),
                label: 'Reset Defaults',
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fill,
                forceTextBandCentered: true,
                icon: Icons.restart_alt,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final button = tester.getRect(find.byKey(const ValueKey('balanced-hmi-button')));
    final icon = tester.getRect(find.byIcon(Icons.restart_alt));
    final label = tester.getRect(find.text('Reset Defaults'));
    final iconGap = label.left - icon.right;
    expect(icon.left - button.left, closeTo(iconGap, 1));
    expect(label.center.dx, closeTo(button.center.dx, 1.5));
  });

  testWidgets('HmiButton switches layout automatically at actual width',
      (tester) async {
    Future<void> pumpAt(double width) => tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.12),
              ),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: HmiButton(
                      key: const ValueKey('adaptive-hmi-button'),
                      label: 'Save',
                      size: HmiButtonSize.large,
                      widthPolicy: HmiButtonWidthPolicy.fill,
                      horizontalPadding: 20,
                      icon: Icons.restart_alt,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    await pumpAt(320);
    expect(
      find.byKey(const ValueKey('hmi-icon-label-label-centered')),
      findsOneWidget,
    );
    final wideButton = tester.getRect(
      find.byKey(const ValueKey('adaptive-hmi-button')),
    );
    final wideIcon = tester.getRect(find.byIcon(Icons.restart_alt));
    final wideLabel = tester.getRect(find.text('Save'));
    expect(wideLabel.center.dx, closeTo(wideButton.center.dx, 1.0));
    expect(wideIcon.center.dy, closeTo(wideLabel.center.dy, 0.01));
    expect(
      wideIcon.left - wideButton.left,
      closeTo(wideIcon.top - wideButton.top, 0.01),
    );

    await pumpAt(120);
    expect(
      find.byKey(const ValueKey('hmi-icon-label-grouped-centered')),
      findsOneWidget,
    );
    final label = tester.widget<Text>(find.text('Save'));
    expect(label.style?.fontSize, 24);
    final narrowButton = tester.getRect(
      find.byKey(const ValueKey('adaptive-hmi-button')),
    );
    final narrowIcon = tester.getRect(find.byIcon(Icons.restart_alt));
    final narrowLabel = tester.getRect(find.text('Save'));
    final groupCenter = (narrowIcon.left + narrowLabel.right) / 2;
    expect(groupCenter, closeTo(narrowButton.center.dx, 0.01));
    expect(narrowIcon.center.dy, closeTo(narrowLabel.center.dy, 0.01));
    expect(tester.takeException(), isNull);
  });

  test('ProcessModeOutlineChrome size tokens alias HmiButton ladder', () {
    expect(
      ProcessModeOutlineChrome.defaultHeight,
      HmiButtonMetrics.heroHeight,
    );
    expect(
      ProcessModeOutlineChrome.labelSize,
      HmiTypography.buttonHeroFontSize,
    );
    expect(
      ProcessModeOutlineChrome.iconSize,
      HmiButtonMetrics.heroIconSize,
    );
    expect(ProcessModeOutlineChrome.engineerWireIconVisualSize, 28);
    expect(
      ProcessModeOutlineChrome.laserEnableHeight,
      HmiButtonMetrics.jumboHeight,
    );
    expect(
      ProcessModeOutlineChrome.laserEnableLabelSize,
      HmiTypography.buttonJumboFontSize,
    );
    expect(
      ProcessModeOutlineChrome.laserEnableIconSize,
      HmiButtonMetrics.jumboIconSize,
    );
  });
}
