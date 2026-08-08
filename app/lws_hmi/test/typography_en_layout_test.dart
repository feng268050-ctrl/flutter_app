import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_display_typography.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/hmi/hmi_dialog_actions.dart';

void _noop() {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EN SettingsSwitchRow uses semantic title sizes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: SettingsSwitchRow(
            title: 'Lens Contamination Detection',
            subtitle:
                'Uses the camera and AI to watch the protective lens during work.',
            value: true,
            onChanged: (_) {},
            emphasis: SettingsSwitchEmphasis.advanced,
          ),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Lens Contamination Detection'));
    expect(title.style?.fontSize, 22);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EN HmiButton large Reset label does not ellipsize at 480w',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: HmiButton(
                key: const ValueKey('reset-en'),
                label: 'Reset To Default',
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fill,
                icon: Icons.restart_alt,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Reset To Default'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Reset To Default'));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.getSize(find.byKey(const ValueKey('reset-en'))).height, 60);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EN MonitorFrostActionButton uses HmiButton medium metrics',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(
            child: MonitorFrostActionButton(
              key: const ValueKey('monitor-pill'),
              label: 'Re-detect',
              variant: CyberButtonVariant.secondary,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HmiButton), findsOneWidget);
    expect(find.text('Re-detect'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Re-detect'));
    expect(text.style?.fontSize, 20); // buttonMedium
    expect(text.style?.color, CyberColors.buttonSecondaryText);
    expect(tester.getSize(find.byType(HmiButton)).height, 52);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EN Alarms Clear groups icon+label; icon matches label size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en', 'US'),
        home: Scaffold(
          body: Center(
            child: MonitorFrostActionButton(
              label: 'Clear',
              variant: CyberButtonVariant.secondary,
              groupIconWithLabel: true,
              leading: Icon(
                Icons.delete_outline,
                color: CyberColors.buttonSecondaryText,
              ),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final hmi = tester.widget<HmiButton>(find.byType(HmiButton));
    expect(hmi.groupIconWithLabel, isTrue);
    expect(find.text('Clear'), findsOneWidget);
    final label = tester.widget<Text>(find.text('Clear'));
    final fontSize = label.style!.fontSize!;
    expect(fontSize, 20);
    // Outer glyph box is fontSize×fontSize (FittedBox may keep Icon layout size).
    final glyphBox = tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere(
          (b) => b.width == fontSize && b.height == fontSize,
        );
    expect(glyphBox.width, fontSize);
    expect(glyphBox.height, fontSize);
    expect(tester.takeException(), isNull);
  });

  test('HmiTypography roles match ladder sizes used by Settings chrome', () {
    const t = HmiTypography();
    expect(t.settingsRowTitle.fontSize, 20);
    expect(t.supporting.fontSize, 16);
    expect(t.navigation.fontSize, 24);
    expect(t.sectionTitle.fontSize, 22);
    expect(t.pageTitle.fontSize, 28);
    expect(t.metricLabel.fontSize, 20);
    expect(t.body.fontSize, 18);
  });

  test('WarnDialogMetrics ladder sizes stay on FrostUI 100% scale', () {
    expect(WarnDialogMetrics.titleSize, 52);
    expect(WarnDialogMetrics.bodySize, 36);
    expect(WarnDialogMetrics.confirmLabelSize, 24);
    expect(WarnDialogMetrics.minTitleSize, 18);
  });

  test('HmiTypography button ladder fonts match Size table', () {
    const t = HmiTypography();
    expect(t.buttonMini.fontSize, 14);
    expect(t.buttonSmall.fontSize, 16);
    expect(t.buttonMedium.fontSize, 20);
    expect(t.buttonLarge.fontSize, 24);
    expect(t.buttonHero.fontSize, 24);
    expect(t.buttonJumbo.fontSize, 32);
  });

  test('EN fixed-width medium/large labels fit TextPainter budgets', () {
    const typography = HmiTypography();
    final medium = HmiButtonMetrics.forSize(HmiButtonSize.medium, typography);
    final large = HmiButtonMetrics.forSize(HmiButtonSize.large, typography);
    final hero = HmiButtonMetrics.forSize(HmiButtonSize.hero, typography);

    double textWidth(String label, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style.copyWith(height: 1.0)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      return painter.width;
    }

    bool fits({
      required String label,
      required HmiButtonMetrics metrics,
      required double buttonWidth,
      double iconSlot = 0,
    }) {
      final budget =
          buttonWidth - 2 * metrics.horizontalPadding - iconSlot;
      return textWidth(label, metrics.textStyle) <= budget;
    }

    // HmiDialogActions / camera overlay / IME equal fixed 196.
    expect(
      fits(label: 'Cancel', metrics: medium, buttonWidth: 196),
      isTrue,
    );
    expect(
      fits(label: 'Confirm', metrics: medium, buttonWidth: 196),
      isTrue,
    );
    expect(
      fits(label: 'Apply', metrics: medium, buttonWidth: 196),
      isTrue,
    );
    expect(
      fits(label: 'OK', metrics: medium, buttonWidth: 280),
      isTrue,
    );

    // Safety tips Agree @ 196 large.
    expect(
      fits(label: 'Agree', metrics: large, buttonWidth: 196),
      isTrue,
    );

    // OTA / control-board actions @ 480 large.
    // Icon is overlaid (does not shrink centered-label budget).
    expect(
      fits(label: 'Update Now', metrics: large, buttonWidth: 480),
      isTrue,
    );
    expect(
      fits(label: 'Check for Updates', metrics: large, buttonWidth: 480),
      isTrue,
    );
    expect(
      fits(label: 'Reset To Default', metrics: large, buttonWidth: 480),
      isTrue,
    );

    // Engineer entry / warn confirm @ 500 hero.
    expect(
      fits(label: 'Confirm & Enter', metrics: hero, buttonWidth: 500),
      isTrue,
    );
    expect(
      fits(label: 'Confirm', metrics: hero, buttonWidth: 500),
      isTrue,
    );
  });

  test('Medium 100% dialog/tip body roles are explicit (not ladder-derived)', () {
    const t = HmiTypography();
    expect(t.dialogBody.fontSize, AppTypography.pageTitleSize); // 28
    expect(t.importantDialogBody.fontSize, AppTypography.dialogTitleSize); // 32
    expect(t.dialogOptionLabel.fontSize, HmiTypography.dialogOptionLabelSize);
    expect(t.engineerTipTitle.fontSize, AppTypography.criticalTitleSize);
    expect(t.engineerTipBody.fontSize, AppTypography.largeDialogTitleSize);
    expect(t.safetyTipBody.fontSize, AppTypography.navigationSize);
    expect(t.reminderBody.fontSize, AppTypography.sectionTitleSize);
    expect(HmiTypography.buttonHeroFontSize, 24);
    expect(t.clock.fontSize, HmiDisplayTypography.clockSize);
    expect(t.dashboardValue.fontSize, HmiDisplayTypography.dashboardValueSize);
  });

  testWidgets('EN HmiDialogActions medium Cancel/Confirm fit equal 196',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en', 'US'),
        home: const Scaffold(
          body: Center(
            child: HmiDialogActions(
              cancelLabel: 'Cancel',
              confirmLabel: 'Confirm',
              onCancel: _noop,
              onConfirm: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    final cancel = tester.widget<Text>(find.text('Cancel'));
    final confirm = tester.widget<Text>(find.text('Confirm'));
    expect(cancel.style?.fontSize, 20);
    expect(confirm.style?.fontSize, 20);
    expect(cancel.overflow, isNot(TextOverflow.ellipsis));
    expect(confirm.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });
}
