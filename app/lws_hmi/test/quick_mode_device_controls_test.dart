import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_outline_button.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_device_controls.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(ProcessModeToast.resetForTest);

  AppServices servicesWith(ModbusRtuClient modbus) {
    return AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: modbus,
    );
  }

  Future<void> pumpControls(
    WidgetTester tester, {
    required ProcessType processType,
    DeviceControlController? controller,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final services = controller?.services ?? servicesWith(_IdleModbus());
    final c =
        controller ?? (DeviceControlController(services)..keySwitchOn = true);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: ProcessModeToastLayer(
              child: Scaffold(
                body: QuickModeDeviceControls(
                  controller: c,
                  processType: processType,
                  laserPreflight: () => null,
                  onEnableConfirmed: () async {},
                  onDisable: () async {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Cancel OsWallClock before Flutter's post-test timer invariant.
    services.wallClock.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('continuous weld Feed shows hold-3s hint', (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);
    expect(
      find.byKey(const ValueKey('device-control-feed-hold-hint')),
      findsOneWidget,
    );
    expect(find.text('Hold 3s to keep on'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    final hint = tester.widget<Text>(
      find.byKey(const ValueKey('device-control-feed-hold-hint')),
    );
    expect(hint.style?.color, ProcessModeOutlineChrome.actionOrange);
  });

  testWidgets('four side-action labels stay at Medium under Large',
      (tester) async {
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      textScaler: const TextScaler.linear(1.12),
    );

    for (final label in ['Manual Gas', 'Auto Wire Feed', 'Feed', 'Retract']) {
      final context = tester.element(find.text(label));
      expect(MediaQuery.textScalerOf(context).scale(100), 100);
    }
  });

  testWidgets('left and right zone dividers share the same Y', (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);
    final left = tester.getRect(
      find.byKey(const ValueKey('quick-mode-zone-divider-left')),
    );
    final right = tester.getRect(
      find.byKey(const ValueKey('quick-mode-zone-divider-right')),
    );
    expect(left.top, closeTo(right.top, 0.5));
  });

  testWidgets('pins left/right groups to screen corners', (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);

    final gas = tester.getRect(
      find.byKey(const ValueKey('device-control-manual-gas')),
    );
    final feed = tester.getRect(
      find.byKey(const ValueKey('device-control-feed')),
    );
    const scale = 0.625; // 800×500 logical viewport on the 1280×800 test view.
    expect(
      gas.left,
      closeTo(ProcessModeDimens.quickSideButtonInset * scale, 1),
    );
    expect(
      gas.width,
      closeTo(ProcessModeDimens.quickSideButtonWidth * scale, 1),
    );
    expect(
      feed.right,
      closeTo(1280 - ProcessModeDimens.quickSideButtonInset * scale, 1),
    );
  });

  testWidgets('side ops pin icon with equal edge insets and clear the label',
      (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);

    for (final entry in [
      (
        const ValueKey('device-control-manual-gas'),
        'Manual Gas',
        Icons.air,
        ProcessModeOutlineChrome.iconLabelClearance,
      ),
      (
        const ValueKey('device-control-feed'),
        'Feed',
        Icons.output,
        ProcessModeOutlineChrome.iconLabelClearance,
      ),
      (
        const ValueKey('device-control-retract'),
        'Retract',
        Icons.output,
        ProcessModeOutlineChrome.iconLabelClearance,
      ),
    ]) {
      final host = tester.element(find.byKey(entry.$1));
      final scale = ProcessModeDimens.dashboardScaleFor(
        MediaQuery.sizeOf(host),
      );
      final button = tester.getRect(find.byKey(entry.$1));
      final label = tester.getRect(find.text(entry.$2));
      final icon = tester.getRect(find.descendant(
        of: find.byKey(entry.$1),
        matching: find.byIcon(entry.$3),
      ));
      final clearance = entry.$4;
      expect(
        find.descendant(
          of: find.byKey(entry.$1),
          matching: find.byKey(const ValueKey('hmi-icon-label-label-centered')),
        ),
        findsOneWidget,
      );
      // Icon left inset equals vertical inset (stable pin).
      expect(icon.left - button.left, closeTo(icon.top - button.top, 1));
      // Label never overlaps the icon (per-button clearance when nudged).
      expect(
        label.left - icon.right,
        greaterThanOrEqualTo(clearance * scale - 0.75),
      );
      // Right chrome at least matches the left icon inset.
      expect(
        button.right - label.right,
        greaterThanOrEqualTo(icon.left - button.left - 1),
      );
    }

    // Short label still centers on the button when it clears the icon.
    final feedButton = tester.getRect(
      find.byKey(const ValueKey('device-control-feed')),
    );
    final feedLabel = tester.getRect(find.text('Feed'));
    expect(feedLabel.center.dx, closeTo(feedButton.center.dx, 1));
  });

  testWidgets('Auto Wire Feed abuts label to icon with no clearance',
      (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);

    const key = ValueKey('device-control-auto-wire-feed');
    final host = tester.element(find.byKey(key));
    final scale = ProcessModeDimens.dashboardScaleFor(
      MediaQuery.sizeOf(host),
    );
    final button = tester.getRect(find.byKey(key));
    final icon = tester.getRect(find.descendant(
      of: find.byKey(key),
      matching: find.byIcon(Icons.sync),
    ));
    final labelFinder = find.descendant(
      of: find.byKey(key),
      matching: find.textContaining('Auto'),
    );
    expect(labelFinder, findsOneWidget);
    final label = tester.getRect(labelFinder);
    final text = tester.widget<Text>(labelFinder);

    expect(icon.left - button.left, closeTo(icon.top - button.top, 1));
    // Nudged path: label starts at icon edge (0 logical px).
    expect(
      label.left - icon.right,
      closeTo(ProcessModeOutlineChrome.noIconLabelClearance * scale, 0.75),
    );
    expect(
      button.right - label.right,
      greaterThanOrEqualTo(icon.left - button.left - 1),
    );
    expect(text.overflow, TextOverflow.ellipsis);
    expect(label.right, lessThanOrEqualTo(button.right + 0.5));
  });

  testWidgets('greys Auto Wire / Feed / Retract outside continuous welding',
      (tester) async {
    await pumpControls(tester, processType: ProcessType.weldCleaning);

    expect(find.byKey(const ValueKey('device-control-manual-gas')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-auto-wire-feed')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-feed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-control-retract')),
      findsOneWidget,
    );

    // Engineer outline chrome: idle orange / disabled brown.
    const idle = ProcessModeOutlineChrome.actionOrange;
    const disabled = ProcessModeOutlineChrome.disabledForeground;
    expect(
      tester.widget<Text>(find.text('Manual Gas')).style?.color,
      idle,
    );
    expect(
      tester.widget<Text>(find.text('Auto Wire Feed')).style?.color,
      disabled,
    );
    expect(
      tester.widget<Text>(find.text('Feed')).style?.color,
      disabled,
    );
    expect(
      tester.widget<Text>(find.text('Retract')).style?.color,
      disabled,
    );
  });

  testWidgets('ignores Feed tap quietly when wire ops are disabled',
      (tester) async {
    await pumpControls(tester, processType: ProcessType.weldCleaning);
    final center =
        tester.getCenter(find.byKey(const ValueKey('device-control-feed')));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.text('Wire Feed Unavailable In This Mode'), findsNothing);
  });

  testWidgets('enables wire ops in continuous welding', (tester) async {
    final controller = DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true
      ..autoWireFeed = false;
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      controller: controller,
    );
    // Idle Engineer outline chrome: orange label (not grey / disabled).
    const idle = ProcessModeOutlineChrome.actionOrange;
    expect(
      tester.widget<Text>(find.text('Auto Wire Feed')).style?.color,
      idle,
    );
    expect(
      tester.widget<Text>(find.text('Feed')).style?.color,
      idle,
    );
    expect(
      tester.widget<Text>(find.text('Retract')).style?.color,
      idle,
    );
  });

  testWidgets('frosts side groups while laser enable is on (still in tree)',
      (tester) async {
    final controller = DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true
      ..laserEnable = true;
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      controller: controller,
    );

    expect(
      find.byKey(const ValueKey('device-control-manual-gas')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('device-control-feed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-control-feed-hold-hint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('laser-enable-region-frost')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('quick-mode-laser-enable')),
      findsOneWidget,
    );

    // Hold hint must sit inside a frosted region (not a sibling above it).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('laser-enable-region-frost')),
        matching: find.byKey(const ValueKey('device-control-feed-hold-hint')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('emission feedback alone does not open Laser Enable session UI',
      (tester) async {
    final controller = DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true
      ..laserOn = true
      ..laserEnable = false;
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      controller: controller,
    );

    expect(find.text('Enable Laser'), findsOneWidget);
    expect(find.text('End Work'), findsNothing);
    expect(
      find.byKey(const ValueKey('device-control-manual-gas')),
      findsOneWidget,
    );
  });

  test('side highlight uses transparent-mid-transparent stops', () {
    final g = ProcessModeTokens.sideOperationHighlight(
      ProcessType.continuousWelding,
    );
    expect(g.colors.length, 3);
    expect(g.colors.first.alpha, 0);
    expect(g.colors[1].alpha, greaterThan(0));
    expect(g.colors.last.alpha, 0);
  });
}

final class _IdleModbus extends ModbusRtuClient {
  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async => true;

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}
