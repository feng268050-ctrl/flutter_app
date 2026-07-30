import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';
import 'package:lws_hmi/gpio/laser_enable_led_holder.dart';
import 'package:lws_hmi/gpio/rgb_led_policy_driver.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  BoardProfile testProfile() => BoardProfile.fromJsonString('''
{
  "board_id": "test",
  "platform": "linux",
  "capabilities": [],
  "helpers": {},
  "configs": {}
}
''');

  late Directory tmp;
  late AppServices services;
  late DangerousOperationsSettings dangerous;
  late WarnAlarmController warn;
  late List<(LedColor, IndicatorMode)> applied;
  late LaserEnableLedHolder holder;
  late RgbLedPolicyDriver driver;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rgb-led-policy-');
    services = AppServices(
      boardProfile: testProfile(),
      sysInfo: StubSysInfo(),
      modbusClient: _IdleModbus(),
    );
    final store = AdvancedSettingsStore(
      preferencePath: '${tmp.path}/advanced-settings.json',
    )..warmRead();
    dangerous = DangerousOperationsSettings(store);
    warn = WarnAlarmController(
      services: services,
      promptQueue: GlobalPromptQueue(
        navigatorKey: GlobalKey<NavigatorState>(),
      ),
      dangerousOperations: dangerous,
    );
    applied = <(LedColor, IndicatorMode)>[];
    holder = LaserEnableLedHolder.instance..clear();
    driver = RgbLedPolicyDriver(
      services: services,
      warnAlarm: warn,
      dangerous: dangerous,
      ledWorkState: holder,
      applyMode: (color, mode) async {
        applied.add((color, mode));
        // Simulate slow GPIO so concurrent refresh can set pending.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
    );
    services.rgbLedPolicy = driver;
  });

  tearDown(() async {
    await driver.dispose();
    await warn.dispose();
    holder.clear();
    await tmp.delete(recursive: true);
  });

  test('manual override suppresses setMode during refresh', () async {
    driver.debugMarkStarted();
    driver.debugSetInputs(primed: true, laserOn: false, laserCommAlarm: false);
    driver.beginManualOverride();
    applied.clear();
    await driver.refresh();
    expect(applied, isEmpty);
  });

  test('endManualOverride resumes and applies modes', () async {
    driver.debugMarkStarted();
    driver.debugSetInputs(primed: true, laserOn: false, laserCommAlarm: false);
    driver.beginManualOverride();
    await driver.refresh();
    expect(applied, isEmpty);

    driver.endManualOverride();
    // endManualOverride schedules refresh asynchronously.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(applied, isNotEmpty);
    expect(
      applied.where((e) => e.$1 == LedColor.red).last.$2,
      IndicatorMode.blink,
    );
  });

  test('concurrent refresh coalesces via pending flag', () async {
    driver.debugMarkStarted();
    driver.debugSetInputs(primed: true, laserOn: false, laserCommAlarm: false);

    final first = driver.refresh();
    // While first apply is in flight, queue another.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = driver.refresh();
    await Future.wait([first, second]);
    // Allow pending loop to finish.
    await Future<void>.delayed(const Duration(milliseconds: 80));

    // At least one full RGB apply (3 colors); pending should cause a second pass.
    expect(applied.length, greaterThanOrEqualTo(6));
  });

  test('green uses LaserEnableLedHolder, not Modbus laser_enable', () async {
    driver.debugMarkStarted();
    driver.debugSetInputs(
      primed: true,
      laserOn: false,
      keySwitchOn: true,
      safetyGroundLock: true,
      cncConnected: false,
    );
    holder.setActive(false);
    applied.clear();
    await driver.refresh();
    expect(
      applied.where((e) => e.$1 == LedColor.green).last.$2,
      IndicatorMode.off,
    );

    holder.setActive(true, workModel: ProcessType.continuousWelding);
    await driver.refresh();
    expect(
      applied.where((e) => e.$1 == LedColor.green).last.$2,
      IndicatorMode.steadyOn,
    );
  });

  test('CNC green follows cncConnected with wireValue 5', () async {
    driver.debugMarkStarted();
    driver.debugSetInputs(
      primed: true,
      laserOn: false,
      keySwitchOn: true,
      safetyGroundLock: false,
      cncConnected: false,
    );
    holder.setActive(false, workModel: ProcessType.cncCutting);
    applied.clear();
    await driver.refresh();
    expect(
      applied.where((e) => e.$1 == LedColor.green).last.$2,
      IndicatorMode.off,
    );

    driver.debugSetInputs(cncConnected: true);
    await driver.refresh();
    expect(
      applied.where((e) => e.$1 == LedColor.green).last.$2,
      IndicatorMode.steadyOn,
    );
  });
}

class _IdleModbus extends ModbusRtuClient {
  _IdleModbus();

  @override
  Future<void> ensurePolling() async {}

  @override
  Future<void> applyHealthWindowMode(String? mode) async {}

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}
