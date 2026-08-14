import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/monitor/presentation/monitor_page.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/machine_status_tab.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_top_tabs.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Monitor has four tabs and AI Vision uses the last index', () {
    expect(MonitorPage.tabCount, 4);
    expect(MonitorPage.tabWorkInformation, 0);
    expect(MonitorPage.tabMachineStatus, 1);
    expect(MonitorPage.tabVideos, 2);
    expect(MonitorPage.tabAiVision, 3);
    expect(
      MonitorRouteArgs.aiVision.initialTabIndex,
      MonitorPage.tabAiVision,
    );
  });

  test('latestAlarmHistoryRows keeps newest 10 by timestamp', () {
    final rows = [
      for (var i = 0; i < 25; i++)
        AlarmLogEntry(
          code: 'H${i.toString().padLeft(3, '0')}',
          title: 'row $i',
          timestamp: DateTime.utc(2026, 8, 14, 12, i),
        ),
    ];
    final visible = latestAlarmHistoryRows(rows);
    expect(visible, hasLength(kMachineAlarmLogsVisibleLimit));
    expect(kMachineAlarmLogsVisibleLimit, 10);
    expect(visible.first.code, 'H024');
    expect(visible.last.code, 'H015');
  });

  test('MachineStatusController still watches hidden Live Status bits', () {
    expect(MachineStatusIds.modbusWatchIds, contains(MachineStatusIds.laserOn));
    expect(
      MachineStatusIds.modbusWatchIds,
      contains(MachineStatusIds.airValveOn),
    );
    expect(
      MachineStatusIds.modbusWatchIds,
      contains(MachineStatusIds.wireFeedingOn),
    );
  });

  testWidgets('Machine Status shows four tiles, Device Health, and Alarm Logs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[HmiTypography()],
        ),
        home: const Scaffold(body: MachineStatusTab()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Safety Clamp'), findsOneWidget);
    expect(find.text('Gun Switch'), findsOneWidget);
    expect(find.text('Red Pointer'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Laser'), findsNothing);
    expect(find.text('Gas Flow'), findsNothing);
    expect(find.text('Wire Feeder'), findsNothing);

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(
      find.byType(SliverPersistentHeader, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Active Alarms'), findsNothing);

    final liveSize = tester.getSize(
      find.byKey(const ValueKey('machine-status-live-status')),
    );
    expect(liveSize.height, 800);
    final tileRect = tester.getRect(find.byType(MonitorStatusTile).first);
    expect(tileRect.top, greaterThan(400),
        reason: 'run tiles sit in the lower half of the first viewport');
    expect(800 - tileRect.bottom, lessThan(MonitorDimens.pad + 40),
        reason: 'run tiles sit at the bottom of Live Status, not sticky');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('machine-status-device-health')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Device Health'), findsOneWidget);
    expect(find.text('Pump Comm'), findsOneWidget);
    expect(find.text('Gun Comm'), findsOneWidget);
    expect(find.text('Camera Comm'), findsNothing);
    expect(find.text('Feeder Comm'), findsOneWidget);
    final gunWidth = tester
        .getSize(
          find.ancestor(
            of: find.text('Gun Comm'),
            matching: find.byType(MonitorCommCard),
          ),
        )
        .width;
    final pumpWidth = tester
        .getSize(
          find.ancestor(
            of: find.text('Pump Comm'),
            matching: find.byType(MonitorCommCard),
          ),
        )
        .width;
    expect(gunWidth, pumpWidth);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('machine-status-alarm-logs')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Alarm Log'), findsOneWidget);
    final headerFill = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('machine-status-alarm-logs')),
    );
    expect(headerFill.color, Colors.transparent);
    expect(headerFill.color.alpha, 0);
    final divider = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey('machine-status-alarm-logs')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == ProductTopTabs.dividerColor,
        ),
      ),
    );
    expect(divider.color, ProductTopTabs.dividerColor);
    expect(
      find.byKey(const ValueKey('machine-status-alarm-logs-clip')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('machine-status-alarm-logs')))
          .width,
      1280,
    );
    final clear = tester.widget<MonitorFrostActionButton>(
      find.byKey(const ValueKey('machine-status-clear-alarm-logs')),
    );
    expect(clear.label, 'Clear');
    expect(clear.size, HmiButtonSize.small);
    expect(clear.variant, CyberButtonVariant.secondary);
    expect(clear.onPressed, isNull);
  });
}
