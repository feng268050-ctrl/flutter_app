import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_dialog_body.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

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
    expect(title.style?.fontSize, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EN HmiButton large Reset label does not ellipsize at 340w',
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
              width: 340,
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
    expect(text.style?.fontSize, 18); // buttonMedium
    expect(text.style?.color, CyberColors.buttonSecondaryText);
    expect(tester.getSize(find.byType(HmiButton)).height, 52);
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
}
