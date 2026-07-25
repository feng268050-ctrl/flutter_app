import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  Future<ProcessLibraryController> seedController({
    List<ProcessPreset>? extras,
  }) async {
    final database = sqlite3.openInMemory();
    addTearDown(database.dispose);
    final repository = SqliteProcessLibraryRepository(database: database);
    await repository.open();
    final presets = <ProcessPreset>[
      _engineer(
        uuid: 'eng-ss',
        name: 'Stainless Steel-2mm',
        builtin: true,
      ),
      _engineer(
        uuid: 'user-1',
        name: 'My Weld',
        builtin: false,
        kind: ProcessPresetKind.user,
      ),
      _quick(uuid: 'quick-hand'),
      ...?extras,
    ];
    await repository.replaceBuiltins(
      source: 'test',
      meta: ProcessLibraryMeta(
        source: 'test',
        libraryVersion: '1',
        schemaVersion: 1,
        contentSha256: 'hash',
        installedAtMs: 1,
        rowCount: presets.length,
      ),
      presets: presets.where((p) => p.kind != ProcessPresetKind.user).toList(),
    );
    for (final user in presets.where((p) => p.kind == ProcessPresetKind.user)) {
      await repository.saveUser(user);
    }
    final controller = ProcessLibraryController(
      repository: repository,
      importer: ProcessLibraryImporter(
        repository: repository,
        deviceModel: 'ynh960',
        manifestAsset: 'missing.json',
        bundle: _EmptyBundle(),
      ),
      applier: ProcessParameterApplier(
        modbus: _UnusedModbus(),
        isSafeToApply: () async => false,
      ),
    );
    addTearDown(controller.close);
    await controller.initialize();
    return controller;
  }

  testWidgets('EngineerModePage loads built-in form and favorites',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: ProcessLibraryScope(
          controller: controller,
          child: const EngineerModePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
        find.byKey(const ValueKey('engineer-parameter-form')), findsOneWidget);
    expect(find.text('Stainless Steel-2mm'), findsOneWidget);
    expect(find.text('Current Process Parameter'), findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-action-copy')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-save')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-reset')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-apply')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-reset-default')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-action-save-favorite')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-parameters-header-divider')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-parameters-actions-divider')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-param-process.laser_power')),
        findsOneWidget);

    final deviceWidth = tester
        .getSize(find.byKey(const ValueKey('engineer-device-panel-container')))
        .width;
    final parameterWidth = tester
        .getSize(find.byKey(const ValueKey('engineer-parameters-panel')))
        .width;
    expect(parameterWidth / deviceWidth, closeTo(2, 0.05));

    final continuousTab = tester.widget<Text>(find.text('Continuous').first);
    expect(continuousTab.style?.fontSize, 16);
  });

  testWidgets('Quick handoff opens unsaved draft', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const EngineerModePage(
            initialProcessType: ProcessType.continuousWelding,
            initialPresetUuid: 'quick-hand',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
        find.byKey(const ValueKey('engineer-mode-draft-uuid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('engineer-mode-draft-uuid')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('engineer-action-save')), findsOneWidget);
  });

  testWidgets('More Favorites sheet lists built-in and user', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: ProcessLibraryScope(
          controller: controller,
          child: const EngineerModePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.byKey(const ValueKey('engineer-more-favorites')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Favorites'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('engineer-preset-eng-ss')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('engineer-preset-user-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('engineer-preset-user-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('engineer-mode-name')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('engineer-mode-name')),
        matching: find.text('My Weld'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('engineer-action-save')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('engineer-action-delete')), findsOneWidget);
  });
}

ProcessPreset _engineer({
  required String uuid,
  required String name,
  required bool builtin,
  ProcessPresetKind kind = ProcessPresetKind.engineerPreset,
}) {
  return ProcessPreset(
    uuid: uuid,
    name: name,
    kind: kind,
    source: builtin ? 'test' : 'user',
    isBuiltin: builtin,
    processType: ProcessType.continuousWelding,
    materialType: MaterialType.stainlessSteel,
    materialName: 'Stainless Steel',
    thickness: 2,
    gear: 2,
    parameters: ProcessParameters({
      'process.laser_power': 55,
      'process.blowing_delay': 100,
      'process.gas_off_delay': 200,
      'process.swing_frequency': 50,
      'process.swing_width': 2,
      'process.light_off_delay': 0,
      'process.power_ramp_up_duration': 0,
      'process.power_ramp_down_duration': 0,
      'process.wire_feeding_speed': 10,
      'process.back_draw_length': 1,
      'process.back_draw_speed': 5,
      'process.wire_filling_length': 1,
      'process.wire_filling_delay': 0,
    }),
    createdAtMs: 1,
    updatedAtMs: 1,
  );
}

ProcessPreset _quick({required String uuid}) {
  return ProcessPreset(
    uuid: uuid,
    name: 'Quick handoff',
    kind: ProcessPresetKind.quick,
    source: 'test',
    isBuiltin: true,
    processType: ProcessType.continuousWelding,
    materialType: MaterialType.stainlessSteel,
    materialName: 'Stainless Steel',
    thickness: 1.5,
    gear: 1,
    parameters: ProcessParameters({
      'process.laser_power': 42,
      'process.blowing_delay': 50,
      'process.gas_off_delay': 50,
      'process.swing_frequency': 40,
      'process.swing_width': 1,
      'process.light_off_delay': 0,
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

final class _UnusedModbus extends ModbusRtuClient {}
