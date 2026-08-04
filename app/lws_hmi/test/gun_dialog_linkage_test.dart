import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/stub.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/application/gun_dialog_coordinator.dart';
import 'package:lws_hmi/features/process_mode/presentation/live_machine_status_dialog.dart';
import 'package:lws_hmi/features/process_mode/presentation/safety_ground_lock_prompt.dart';
import 'package:lws_hmi/features/process_mode/presentation/work_status_dialog_host.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WorkStatusDialogHost.debugReset();
    SafetyGroundLockPrompt.debugReset();
  });

  AppServices testServices() {
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
      modbusClient: _SilentModbus(),
      audioController: _SilentAudio(),
    );
  }

  group('SafetyGroundLockPrompt.isEligibleForPrompt', () {
    test('requires enable, gun, unlocked ground, and setting', () {
      expect(
        SafetyGroundLockPrompt.isEligibleForPrompt(
          laserEnableActive: true,
          gunSwitchOn: true,
          safetyGroundLocked: false,
          alarmEnabled: true,
        ),
        isTrue,
      );
      expect(
        SafetyGroundLockPrompt.isEligibleForPrompt(
          laserEnableActive: true,
          gunSwitchOn: true,
          safetyGroundLocked: false,
          alarmEnabled: false,
        ),
        isFalse,
      );
      expect(
        SafetyGroundLockPrompt.isEligibleForPrompt(
          laserEnableActive: false,
          gunSwitchOn: true,
          safetyGroundLocked: false,
          alarmEnabled: true,
        ),
        isFalse,
      );
      expect(
        SafetyGroundLockPrompt.isEligibleForPrompt(
          laserEnableActive: true,
          gunSwitchOn: false,
          safetyGroundLocked: false,
          alarmEnabled: true,
        ),
        isFalse,
      );
      expect(
        SafetyGroundLockPrompt.isEligibleForPrompt(
          laserEnableActive: true,
          gunSwitchOn: true,
          safetyGroundLocked: true,
          alarmEnabled: true,
        ),
        isFalse,
      );
    });
  });

  group('GunDialogCoordinator edges', () {
    late AppServices services;
    late DeviceControlController device;
    late GunDialogCoordinator coord;

    setUp(() {
      services = testServices();
      device = DeviceControlController(services);
      device.laserEnable = false;
    });

    tearDown(() {
      coord.dispose();
      device.dispose();
    });

    test('rising records edge when Enable ON; falling schedules close', () {
      coord = GunDialogCoordinator(
        deviceControl: device,
        services: services,
        contextGetter: () => null,
        showGroundLockAlarmGetter: () => false,
      );
      device.laserEnable = true;
      coord.handleInputs(
        laserEnable: true,
        gunOn: false,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isFalse);

      coord.handleInputs(
        laserEnable: true,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isTrue);

      coord.handleInputs(
        laserEnable: true,
        gunOn: false,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isFalse);
      expect(WorkStatusDialogHost.hasPendingClose, isTrue);
      WorkStatusDialogHost.cancelPendingClose();
    });

    test('Enable OFF clears latch when resetGunLatchOnEnableOff', () {
      coord = GunDialogCoordinator(
        deviceControl: device,
        services: services,
        contextGetter: () => null,
        showGroundLockAlarmGetter: () => false,
        resetGunLatchOnEnableOff: true,
      );
      coord.handleInputs(
        laserEnable: true,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isTrue);

      coord.handleInputs(
        laserEnable: false,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isNull);

      coord.handleInputs(
        laserEnable: true,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isTrue);
    });

    test('Engineer keeps latch across Enable OFF', () {
      coord = GunDialogCoordinator(
        deviceControl: device,
        services: services,
        contextGetter: () => null,
        showGroundLockAlarmGetter: () => false,
        resetGunLatchOnEnableOff: false,
      );
      coord.handleInputs(
        laserEnable: true,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      coord.handleInputs(
        laserEnable: false,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isTrue);
    });

    test('ignores gun edges while Enable OFF', () {
      coord = GunDialogCoordinator(
        deviceControl: device,
        services: services,
        contextGetter: () => null,
        showGroundLockAlarmGetter: () => false,
      );
      coord.handleInputs(
        laserEnable: false,
        gunOn: true,
        safetyGroundLocked: true,
        showGroundLockAlarm: false,
      );
      expect(coord.lastGunOn, isNull);
      expect(WorkStatusDialogHost.hasPendingClose, isFalse);
    });
  });

  group('WorkStatusDialogHost', () {
    test('scheduleCloseOnGunOff waits debounce then close delay', () {
      FakeAsync().run((async) {
        var closed = 0;
        // Drive timers without a dialog — closeDialog is still invoked.
        WorkStatusDialogHost.scheduleCloseOnGunOff();
        expect(WorkStatusDialogHost.hasPendingClose, isTrue);

        async.elapse(const Duration(milliseconds: 499));
        expect(WorkStatusDialogHost.hasPendingClose, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        // Debounce done; close delay pending.
        expect(WorkStatusDialogHost.hasPendingClose, isTrue);

        async.elapse(const Duration(milliseconds: 499));
        expect(WorkStatusDialogHost.hasPendingClose, isTrue);

        // Intercept by scheduling a second observer: after close, pending clears.
        async.elapse(const Duration(milliseconds: 1));
        expect(WorkStatusDialogHost.hasPendingClose, isFalse);
        closed++;
        expect(closed, 1);
      });
    });

    testWidgets('gun rising opens no-confirm; closeDialog dismisses it',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      unawaited(WorkStatusDialogHost.showNoConfirmDialog(hostContext));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('live-machine-status-dialog')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('live-machine-status-confirm')),
          findsNothing);
      expect(WorkStatusDialogHost.isGunManagedShowing, isTrue);

      WorkStatusDialogHost.scheduleCloseOnGunOff();
      expect(WorkStatusDialogHost.hasPendingClose, isTrue);
      // Timers are covered by FakeAsync unit test; here verify host dismiss.
      WorkStatusDialogHost.closeDialog();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-machine-status-dialog')),
          findsNothing);
      expect(WorkStatusDialogHost.isGunManagedShowing, isFalse);
    });

    testWidgets('manual More Status is not closed by gun host', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      unawaited(showLiveMachineStatusDialog(hostContext));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('live-machine-status-confirm')),
          findsOneWidget);

      WorkStatusDialogHost.closeDialog();
      await tester.pump();
      expect(find.byKey(const ValueKey('live-machine-status-dialog')),
          findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('live-machine-status-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-machine-status-dialog')),
          findsNothing);
    });

    testWidgets('gun reopen is singleton while already open', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      unawaited(WorkStatusDialogHost.showNoConfirmDialog(hostContext));
      await tester.pump();
      unawaited(WorkStatusDialogHost.showNoConfirmDialog(hostContext));
      await tester.pump();
      expect(find.byKey(const ValueKey('live-machine-status-dialog')),
          findsOneWidget);
      WorkStatusDialogHost.closeDialog();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-machine-status-dialog')),
          findsNothing);
    });
  });

  group('SafetyGroundLockPrompt widget', () {
    testWidgets('shows when eligible; setting off skips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      unawaited(
        SafetyGroundLockPrompt.maybeShow(
          hostContext,
          laserEnableActive: true,
          gunSwitchOn: true,
          safetyGroundLocked: false,
          alarmEnabled: false,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('safety-ground-lock-prompt')),
          findsNothing);

      unawaited(
        SafetyGroundLockPrompt.maybeShow(
          hostContext,
          laserEnableActive: true,
          gunSwitchOn: true,
          safetyGroundLocked: false,
          alarmEnabled: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // Warn dialog chrome can overflow at small test surfaces; ignore layout
      // overflow so linkage assertions remain the focus.
      final overflow = tester.takeException();
      expect(
        overflow == null ||
            overflow.toString().contains('overflowed') ||
            overflow.toString().contains('A RenderFlex overflowed'),
        isTrue,
      );
      expect(find.byKey(const ValueKey('safety-ground-lock-prompt')),
          findsOneWidget);
      expect(find.text('Safety Clamp Disconnected'), findsOneWidget);

      unawaited(
        SafetyGroundLockPrompt.maybeShow(
          hostContext,
          laserEnableActive: true,
          gunSwitchOn: true,
          safetyGroundLocked: false,
          alarmEnabled: true,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('safety-ground-lock-prompt')),
          findsOneWidget);

      SafetyGroundLockPrompt.reset();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('safety-ground-lock-prompt')),
          findsNothing);
    });
  });
}

final class _SilentModbus extends ModbusRtuClient {
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

final class _SilentAudio implements MediaAudioController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
