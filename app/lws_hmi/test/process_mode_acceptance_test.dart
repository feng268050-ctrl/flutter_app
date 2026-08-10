import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_library/presentation/quick_mode_page.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_carry.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:sqlite3/sqlite3.dart';

/// U6 in-repo acceptance: page chrome + Modbus-sim apply paths (no pixel goldens).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    QuickModeSelectionCarry.clear();
    LaserEnableReminderGate.resetForTest();
  });

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  BoardProfile testProfile() => BoardProfile.fromJsonString('''
{
  "board_id": "test",
  "platform": "linux",
  "capabilities": [],
  "helpers": {},
  "configs": {}
}
''');

  AppServices servicesWith(ModbusRtuClient modbus) => AppServices(
        boardProfile: testProfile(),
        sysInfo: StubSysInfo(),
        modbusClient: modbus,
      );

  Future<ProcessLibraryController> seedQuickController(
    _SimModbus modbus, {
    required Future<ProcessApplyFailure?> Function() interlockFailure,
  }) async {
    final database = sqlite3.openInMemory();
    addTearDown(database.dispose);
    final repository = SqliteProcessLibraryRepository(database: database);
    await repository.open();
    await repository.replaceBuiltins(
      source: 'test',
      meta: const ProcessLibraryMeta(
        source: 'test',
        libraryVersion: '1',
        schemaVersion: 1,
        contentSha256: 'hash',
        installedAtMs: 1,
        rowCount: 2,
      ),
      presets: [
        _quick(
          uuid: 'ss-1-1',
          gear: 1,
          thickness: 1,
          material: MaterialType.stainlessSteel,
          laserPower: 40,
        ),
        _quick(
          uuid: 'ss-2-2',
          gear: 2,
          thickness: 2,
          material: MaterialType.stainlessSteel,
          laserPower: 55,
        ),
      ],
    );
    final controller = ProcessLibraryController(
      repository: repository,
      importer: ProcessLibraryImporter(
        repository: repository,
        deviceModel: 'ynh960',
        manifestAsset: 'missing.json',
        bundle: _EmptyBundle(),
      ),
      applier: ProcessParameterApplier(
        modbus: modbus,
        interlockFailure: interlockFailure,
      ),
    );
    addTearDown(controller.close);
    await controller.initialize();
    return controller;
  }

  Future<ProcessLibraryController> seedEngineerController(
    _SimModbus modbus,
  ) async {
    final database = sqlite3.openInMemory();
    addTearDown(database.dispose);
    final repository = SqliteProcessLibraryRepository(database: database);
    await repository.open();
    await repository.replaceBuiltins(
      source: 'test',
      meta: const ProcessLibraryMeta(
        source: 'test',
        libraryVersion: '1',
        schemaVersion: 1,
        contentSha256: 'hash',
        installedAtMs: 1,
        rowCount: 1,
      ),
      presets: [
        _engineer(uuid: 'eng-ss', name: 'Stainless Steel-2mm'),
      ],
    );
    final controller = ProcessLibraryController(
      repository: repository,
      importer: ProcessLibraryImporter(
        repository: repository,
        deviceModel: 'ynh960',
        manifestAsset: 'missing.json',
        bundle: _EmptyBundle(),
      ),
      applier: ProcessParameterApplier(
        modbus: modbus,
        interlockFailure: () async => null,
      ),
    );
    addTearDown(controller.close);
    await controller.initialize();
    return controller;
  }

  testWidgets('QuickModePage hosts DeviceControlBar under AppScope',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _SimModbus();
    final controller = await seedQuickController(
      modbus,
      interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
    );
    await tester.pumpWidget(
      AppScope(
        services: servicesWith(modbus),
        child: MaterialApp(
          home: ProcessLibraryScope(
            controller: controller,
            child: const QuickModePage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('quick-mode-laser-dashboard')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-manual-gas')),
        findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-mode-laser-enable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('device-control-feed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-control-retract')),
      findsOneWidget,
    );

    final gasLeft = tester
        .getTopLeft(find.byKey(const ValueKey('device-control-manual-gas')));
    final feedRight =
        tester.getTopRight(find.byKey(const ValueKey('device-control-feed')));
    final laser = tester.getRect(
      find.byKey(const ValueKey('quick-mode-laser-enable')),
    );
    const quickControlScale = 0.625;
    expect(
      gasLeft.dx,
      closeTo(ProcessModeDimens.quickSideButtonInset * quickControlScale, 1),
    );
    expect(
      feedRight.dx,
      closeTo(
        1280 - ProcessModeDimens.quickSideButtonInset * quickControlScale,
        1,
      ),
    );
    expect(laser.bottom, closeTo(800, 1));
    expect(
      ProcessModeDimens.dashboardInnerSize,
      ProcessModeDimens.dashboardInnerRing -
          2 * ProcessModeDimens.dashboardInnerStroke,
    );
    expect(
      ProcessModeDimens.dashboardInnerStroke,
      ProcessModeDimens.dashboardOuterStroke,
    );
    expect(
      ProcessModeDimens.dashboardLineRing,
      ProcessModeDimens.dashboardOuterRing +
          ProcessModeDimens.dashboardLineStroke,
    );
  });

  testWidgets('CNC hides DeviceControlBar', (tester) async {
    await setDesignSurface(tester);
    final modbus = _SimModbus();
    final controller = await seedQuickController(
      modbus,
      interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
    );
    await tester.pumpWidget(
      AppScope(
        services: servicesWith(modbus),
        child: MaterialApp(
          home: ProcessLibraryScope(
            controller: controller,
            child: const QuickModePage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(
      find.byKey(const ValueKey('quick-mode-process-wheel')),
      const Offset(0, -ProcessModeDimens.wheelItemHeight * 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('quick-mode-cnc-guide')), findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-bar')), findsNothing);
  });

  testWidgets('Quick selection debounce applies process group via Modbus sim',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _SimModbus();
    final controller = await seedQuickController(
      modbus,
      interlockFailure: () async => null,
    );
    await tester.pumpWidget(
      AppScope(
        services: servicesWith(modbus),
        child: MaterialApp(
          home: ProcessLibraryScope(
            controller: controller,
            child: const QuickModePage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Initial matched row (ss-1-1) debounce → process write + type write.
    await tester.pump(const Duration(milliseconds: 350));

    expect(modbus.groupWrites, greaterThanOrEqualTo(1));
    expect(modbus.attributes['process.laser_power'], 40);
    expect(modbus.attributes['control.process_type'], 0);
  });

  testWidgets('Quick laser hold confirms, reapplies process, then enables',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _SimModbus();
    final controller = await seedQuickController(
      modbus,
      interlockFailure: () async => null,
    );
    await tester.pumpWidget(
      AppScope(
        services: servicesWith(modbus),
        child: MaterialApp(
          home: ProcessLibraryScope(
            controller: controller,
            child: const QuickModePage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final writesBeforeEnable = modbus.groupWrites;

    final laser = find.byKey(const ValueKey('quick-mode-laser-enable'));
    final gesture = await tester.startGesture(tester.getCenter(laser));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 310));
    await gesture.up();
    await tester.pump();

    expect(find.byKey(const ValueKey('laser-enable-reminder')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('laser-enable-reminder-confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(modbus.groupWrites, greaterThan(writesBeforeEnable));
    expect(modbus.control['control.wire_work'], isFalse);
    expect(modbus.control['control.laser_enable'], isTrue);
  });

  testWidgets('Quick hides unsafe status banner when LaserWorkGuard blocks',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _SimModbus()
      ..attributes[LaserWorkGuard.laserEnableAttribute] = true;
    final services = servicesWith(modbus);
    final controller = await seedQuickController(
      modbus,
      interlockFailure: () async {
        final block = await LaserWorkGuard.processChangeBlock(services);
        return switch (block) {
          null => null,
          ProcessChangeBlockReason.statusUnavailable =>
            ProcessApplyFailure.statusUnavailable,
          ProcessChangeBlockReason.laserActive =>
            ProcessApplyFailure.unsafeMachineState,
          ProcessChangeBlockReason.wireFeeding =>
            ProcessApplyFailure.wireFeedingActive,
        };
      },
    );
    // Mirror status bits for the guard group reads.
    modbus.status[LaserWorkGuard.laserOnAttribute] = false;
    modbus.status[LaserWorkGuard.wireFeedingOnAttribute] = false;
    modbus.control[LaserWorkGuard.laserEnableAttribute] = true;

    // No AppScope: avoids Record Work camera probe timers in this unit test.
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const QuickModePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Laser work in progress'), findsNothing);
    expect(
      find.byKey(const ValueKey('quick-mode-status-message')),
      findsNothing,
    );
    // lws-ui sendData still writes process regs while laser enable is on;
    // process_type must stay unchanged under the live-tune path.
    expect(modbus.groupWrites, greaterThanOrEqualTo(1));
    expect(modbus.attributes['control.process_type'], 0);
  });

  testWidgets('Engineer mode omits legacy Copy Reset Apply controls',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _SimModbus();
    final controller = await seedEngineerController(modbus);
    await tester.pumpWidget(
      AppScope(
        services: servicesWith(modbus),
        child: MaterialApp(
          home: ProcessLibraryScope(
            controller: controller,
            child: const EngineerModePage(initialPresetUuid: 'eng-ss'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const ValueKey('engineer-device-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-action-copy')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-reset')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-apply')), findsNothing);
    expect(modbus.groupWrites, 0);
  });
}

ProcessPreset _quick({
  required String uuid,
  required int gear,
  required double thickness,
  required MaterialType material,
  required double laserPower,
}) {
  return ProcessPreset(
    uuid: uuid,
    name: '${material.englishName}-$thickness',
    kind: ProcessPresetKind.quick,
    source: 'test',
    isBuiltin: true,
    processType: ProcessType.continuousWelding,
    materialType: material,
    materialName: material.englishName,
    thickness: thickness,
    gear: gear,
    parameters: ProcessParameters({
      'process.laser_power': laserPower,
      'process.laser_frequency': 1000,
      'process.laser_duty_cycle': 50,
    }),
    createdAtMs: 1,
    updatedAtMs: 1,
  );
}

ProcessPreset _engineer({
  required String uuid,
  required String name,
}) {
  return ProcessPreset(
    uuid: uuid,
    name: name,
    kind: ProcessPresetKind.engineerPreset,
    source: 'test',
    isBuiltin: true,
    processType: ProcessType.continuousWelding,
    materialType: MaterialType.stainlessSteel,
    materialName: 'Stainless steel',
    thickness: 2,
    gear: 1,
    parameters: ProcessParameters({
      'process.laser_power': 50,
      'process.laser_frequency': 1000,
      'process.laser_duty_cycle': 50,
      'process.swing_width': 2,
      'process.swing_frequency': 100,
    }),
    createdAtMs: 1,
    updatedAtMs: 1,
  );
}

final class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('missing asset $key');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    throw FlutterError('missing asset $key');
  }
}

/// Stateful Modbus sim for U6 apply + LaserWorkGuard group reads.
final class _SimModbus extends ModbusRtuClient {
  _SimModbus() {
    for (final spec in ProcessParameterCatalog.specs) {
      attributes[spec.key] = 10.0;
    }
    control['control.accessory_model_1'] = 0;
    control['control.accessory_model_2'] = 0;
    control['control.gun_drive_type'] = 1;
    control['control.gun_swing_range_mode'] = 7;
    attributes['control.process_type'] = 0;
    control[LaserWorkGuard.laserEnableAttribute] = false;
    control['control.manual_gas'] = false;
    control['control.process_type'] = 0;
    status[LaserWorkGuard.laserOnAttribute] = false;
    status[LaserWorkGuard.wireFeedingOnAttribute] = false;
    status['machine.key_switch_on'] = true;
    status['machine.emergency_stop'] = false;
    status['machine.air_valve_on'] = false;
  }

  final Map<String, Object?> attributes = {};
  final Map<String, Object?> control = {};
  final Map<String, Object?> status = {};
  int groupWrites = 0;

  @override
  Future<void> ensurePolling() async {}

  @override
  Future<void> applyHealthWindowMode(String? mode) async {}

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();

  @override
  Future<bool> writeGroup(
    String groupId,
    Map<String, Object?> values,
  ) async {
    groupWrites += 1;
    attributes.addAll(values);
    if (groupId == 'control') {
      control.addAll(values);
    }
    return true;
  }

  @override
  Future<bool> writeHoldingRegisters(
    int address,
    List<int> words,
  ) async {
    if (address != 0x0050 || words.length != 5) {
      return false;
    }
    control['control.accessory_model_1'] = words[0];
    control['control.accessory_model_2'] = words[1];
    control['control.gun_drive_type'] = words[2];
    control['control.gun_swing_range_mode'] = words[3];
    control['control.process_type'] = words[4];
    attributes['control.process_type'] = words[4];
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    return switch (groupId) {
      'control' => {
          ...control,
          'control.process_type': attributes['control.process_type'],
        },
      'status' => Map<String, Object?>.from(status),
      'process' => {
          for (final spec in ProcessParameterCatalog.specs)
            spec.key: attributes[spec.key],
        },
      _ => Map<String, Object?>.from(attributes),
    };
  }

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    attributes[id] = value;
    if (id.startsWith('control.')) {
      control[id] = value;
    }
    return true;
  }

  @override
  Future<Object?> readAttribute(String id) async =>
      attributes[id] ?? control[id] ?? status[id];
}
