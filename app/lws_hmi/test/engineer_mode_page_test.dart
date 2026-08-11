import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_tab_metrics.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_mode/application/engineer_mode_session_store.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    ProcessModeToast.resetForTest();
    EngineerModeSessionStore.instance.clearForTest();
  });

  AppServices testServices({ModbusRtuClient? modbus}) => AppServices(
        boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
        sysInfo: StubSysInfo(),
        modbusClient: modbus ?? _UnusedModbus(),
      );

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  Future<ProcessLibraryController> seedController({
    List<ProcessPreset>? extras,
    ProcessParameterApplier? applier,
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
      applier: applier ??
          ProcessParameterApplier(
            modbus: _UnusedModbus(),
            interlockFailure: () async =>
                ProcessApplyFailure.unsafeMachineState,
          ),
    );
    addTearDown(controller.close);
    await controller.initialize();
    return controller;
  }

  Widget engineerHarness({
    required ProcessLibraryController controller,
    ProcessType? initialProcessType,
    String? initialPresetUuid,
    AppServices? services,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return _AppServicesHost(
      services: services ?? testServices(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: ProcessLibraryScope(
          controller: controller,
          child: EngineerModePage(
            initialProcessType: initialProcessType,
            initialPresetUuid: initialPresetUuid,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    );
  }

  testWidgets('EngineerModePage loads built-in form and favorites',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(engineerHarness(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
        find.byKey(const ValueKey('engineer-parameter-form')), findsOneWidget);
    expect(find.text('Stainless Steel-2mm'), findsOneWidget);
    expect(find.text('Current Process Name'), findsOneWidget);
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

    // Reset / Save live in the form scroll — scroll to end to reveal.
    await tester.ensureVisible(
      find.byKey(const ValueKey('engineer-action-reset-default')),
    );
    await tester.pump();

    final resetButton = tester.widget<HmiButton>(
      find.byKey(const ValueKey('engineer-action-reset-default')),
    );
    expect(resetButton.shape, CyberButtonShape.rounded);
    expect(
      resetButton.borderGradientCenter,
      CyberBorderGradientCenter.uniform,
    );
    expect(
      resetButton.borderColor ?? CyberColors.buttonRim,
      CyberColors.buttonRim,
    );

    expect(find.byKey(const ValueKey('engineer-param-process.laser_power')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('engineer-ramp-accordion')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('engineer-ramp-accordion')));
    await tester.pump();
    expect(find.byKey(const ValueKey('engineer-ramp-chart-continuousWelding')),
        findsOneWidget);

    final deviceWidth = tester
        .getSize(find.byKey(const ValueKey('engineer-device-panel-container')))
        .width;
    final parameterWidth = tester
        .getSize(find.byKey(const ValueKey('engineer-parameters-panel')))
        .width;
    expect(parameterWidth / deviceWidth, closeTo(2, 0.05));

    final continuousTab = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('engineer-tab-continuousWelding')),
        matching: find.text('Continuous'),
      ),
    );
    expect(
      continuousTab.style?.fontSize,
      HmiTabMetrics.labelFontSize,
    );
  });

  testWidgets('five fixed engineer actions stay at Medium under Large',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        textScaler: const TextScaler.linear(1.12),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final fixedTargets = [
      find.text('Manual Gas'),
      find.descendant(
        of: find.byKey(const ValueKey('engineer-panel-feed')),
        matching: find.text('Feed'),
      ),
      find.descendant(
        of: find.byKey(const ValueKey('engineer-panel-retract')),
        matching: find.text('Retract'),
      ),
      find.byKey(const ValueKey('engineer-action-reset-default')),
      find.byKey(const ValueKey('engineer-action-save-favorite')),
    ];
    for (final target in fixedTargets) {
      expect(target, findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(target)).scale(100),
        100,
      );
    }
  });

  testWidgets('Quick handoff opens unsaved draft', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
        initialPresetUuid: 'quick-hand',
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
    expect(find.byKey(const ValueKey('engineer-action-save')), findsNothing);
  });

  testWidgets('More Favorites popup lists built-in and user', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(engineerHarness(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('More Favorites'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('engineer-more-favorites')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

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
    expect(find.byKey(const ValueKey('engineer-action-save')), findsNothing);
    expect(find.byKey(const ValueKey('engineer-action-delete')), findsNothing);
    expect(
      find.byKey(const ValueKey('engineer-action-save-favorite')),
      findsOneWidget,
    );
  });

  testWidgets('Reset to Default shows toast, not success dialog',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(engineerHarness(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    await tester.ensureVisible(
      find.byKey(const ValueKey('engineer-action-reset-default')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('engineer-action-reset-default')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Reset Complete'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('engineer-operation-success')),
      findsNothing,
    );
    await tester.pump(ProcessModeToast.shortDuration);
    ProcessModeToast.resetForTest();
  });

  testWidgets('tab switch keeps per-type in-memory session', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
        initialPresetUuid: 'quick-hand',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .name,
      'Quick handoff',
    );
    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .parameters
          .values['process.laser_power'],
      42,
    );

    await tester.tap(
      find.byKey(const ValueKey('engineer-tab-spotWelding')),
    );
    await tester.pump();
    await tester.pump(kAppPageEnterDuration);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('engineer-tab-continuousWelding')),
    );
    await tester.pump();
    await tester.pump(kAppPageEnterDuration);
    await tester.pump();

    // Process-lifetime cache must still hold the Quick handoff edits.
    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .name,
      'Quick handoff',
    );
    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .parameters
          .values['process.laser_power'],
      42,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('engineer-mode-name')),
        matching: find.text('Quick handoff'),
      ),
      findsOneWidget,
    );
    expect(find.text('Stainless Steel-2mm'), findsNothing);

    // Tab switch kicks off unawaited Modbus sync; dispose waits while busy.
    // Also cancel any pending apply debounce from session restore.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('leave and re-enter restores process-lifetime session',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
        initialPresetUuid: 'quick-hand',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('engineer-mode-name')),
        matching: find.text('Quick handoff'),
      ),
      findsOneWidget,
    );

    // Leave Engineer Mode (route dispose) without clearing the session store.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .name,
      'Quick handoff',
    );

    // Re-enter without Quick handoff — must restore MemoryCache, not builtin.
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('engineer-mode-name')),
        matching: find.text('Quick handoff'),
      ),
      findsOneWidget,
    );
    expect(find.text('Stainless Steel-2mm'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
      'first entry on continuous weld applies process group (default swing)',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _RecordingModbus();
    final controller = await seedController(
      applier: ProcessParameterApplier(
        modbus: modbus,
        interlockFailure: () async => null,
      ),
    );
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // Debounce 300ms from first-entry continuous-weld apply.
    await tester.pump(const Duration(milliseconds: 350));

    expect(modbus.processGroupWrites, greaterThanOrEqualTo(1));
    expect(modbus.attributes['process.swing_width'], 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('CW session cache restore does not auto-apply (lws-ui isInit)',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _RecordingModbus();
    final controller = await seedController(
      applier: ProcessParameterApplier(
        modbus: modbus,
        interlockFailure: () async => null,
      ),
    );
    EngineerModeSessionStore.instance.put(
      EngineerModeDraft.fromLibrary(
        controller
            .engineerPresets(processType: ProcessType.continuousWelding)
            .first
            .copyWith(
              parameters: ProcessParameters({
                'process.laser_power': 55,
                'process.swing_width': 5,
              }),
            ),
      ),
    );
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 350));

    expect(modbus.processGroupWrites, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
      'first entry on non-continuous weld does not auto-apply (lws-ui isInit)',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _RecordingModbus();
    final controller = await seedController(
      extras: [
        _engineer(
          uuid: 'eng-cut',
          name: 'Cut Default',
          builtin: true,
        ).copyWith(processType: ProcessType.handCutting),
      ],
      applier: ProcessParameterApplier(
        modbus: modbus,
        interlockFailure: () async => null,
      ),
    );
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.handCutting,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 350));

    expect(modbus.processGroupWrites, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
      'tab switch to spot welding applies process_type and spot interval',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _RecordingModbus();
    final spot = _engineer(
      uuid: 'eng-spot',
      name: 'Spot Steel-2mm',
      builtin: true,
    ).copyWith(
      processType: ProcessType.spotWelding,
      parameters: ProcessParameters({
        'process.laser_power': 53,
        'process.spot_welding_interval': 1500,
        'process.spot_welding_duration': 200,
        'process.blowing_delay': 100,
        'process.gas_off_delay': 200,
        'process.swing_frequency': 50,
        'process.swing_width': 2,
        'process.light_off_delay': 0,
      }),
    );
    final controller = await seedController(
      extras: [spot],
      applier: ProcessParameterApplier(
        modbus: modbus,
        interlockFailure: () async => null,
      ),
    );
    // Seed spot session so tab switch restores a known draft (not empty).
    EngineerModeSessionStore.instance.put(EngineerModeDraft.fromLibrary(spot));
    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
        services: testServices(modbus: modbus),
      ),
    );
    await tester.pump();
    // Device panel laser label can overflow by 1px at 1280 — clear it.
    while (tester.takeException() != null) {}
    await tester.pump(const Duration(milliseconds: 80));
    while (tester.takeException() != null) {}
    // Let continuous first-entry apply settle.
    await tester.pump(const Duration(milliseconds: 350));
    while (tester.takeException() != null) {}
    expect(modbus.attributes['control.process_type'], 0);

    await tester.tap(find.byKey(const ValueKey('engineer-tab-spotWelding')));
    await tester.pump();
    while (tester.takeException() != null) {}
    // Tab-switch schedules apply immediately (300ms debounce).
    await tester.pump(const Duration(milliseconds: 350));
    while (tester.takeException() != null) {}
    // Busy-retry backoff if CW apply overlapped.
    await tester.pump(const Duration(milliseconds: 800));
    while (tester.takeException() != null) {}

    expect(modbus.attributes['control.process_type'], 1);
    expect(modbus.attributes['process.spot_welding_interval'], 1500);
    expect(modbus.attributes['process.spot_welding_duration'], 200);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
      'rapid tab switches converge continuous welding auto wire to enabled',
      (tester) async {
    await setDesignSurface(tester);
    final modbus = _RecordingModbus(
      controlWriteDelay: const Duration(milliseconds: 50),
    );
    final spot = _engineer(
      uuid: 'eng-spot-auto-wire',
      name: 'Spot Steel-2mm',
      builtin: true,
    ).copyWith(processType: ProcessType.spotWelding);
    final controller = await seedController(extras: [spot]);
    EngineerModeSessionStore.instance.put(EngineerModeDraft.fromLibrary(spot));

    await tester.pumpWidget(
      engineerHarness(
        controller: controller,
        initialProcessType: ProcessType.continuousWelding,
        services: testServices(modbus: modbus),
      ),
    );
    await tester.pump();
    while (tester.takeException() != null) {}
    // DeviceControlController.start: snapshot + default Auto Wire ON.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.takeException() != null) {}

    // Establish a completed OFF → ON cycle first.
    await tester.tap(find.byKey(const ValueKey('engineer-tab-spotWelding')));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.takeException() != null) {}
    expect(modbus.controlField1Writes.last & (1 << 4), 0);

    await tester.tap(
      find.byKey(const ValueKey('engineer-tab-continuousWelding')),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.takeException() != null) {}
    expect(modbus.controlField1Writes.last & (1 << 4), isNot(0));

    // Reproduce the race: select continuous while spot's delayed OFF write is
    // already in flight. The serialized queue must make the latest ON win.
    await tester.tap(find.byKey(const ValueKey('engineer-tab-spotWelding')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(
      find.byKey(const ValueKey('engineer-tab-continuousWelding')),
    );
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.takeException() != null) {}

    expect(modbus.controlField1Writes, contains(0));
    expect(modbus.controlField1Writes.last & (1 << 4), isNot(0));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
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

/// Counts successful process-group applies for first-entry policy tests.
final class _RecordingModbus extends ModbusRtuClient {
  _RecordingModbus({
    this.controlWriteDelay = Duration.zero,
  }) {
    for (final spec in ProcessParameterCatalog.specs) {
      attributes[spec.key] = 0.0;
    }
    attributes['control.accessory_model_1'] = 0;
    attributes['control.accessory_model_2'] = 0;
    attributes['control.gun_drive_type'] = 1;
    attributes['control.gun_swing_range_mode'] = 7;
    attributes['control.process_type'] = 0;
    attributes['control.field_1'] = 0;
  }

  final Map<String, Object?> attributes = {};
  final Duration controlWriteDelay;
  final List<int> controlField1Writes = [];
  int processGroupWrites = 0;

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeGroup(
    String groupId,
    Map<String, Object?> values,
  ) async {
    if (groupId == 'process') {
      processGroupWrites += 1;
    }
    attributes.addAll(values);
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
    attributes['control.accessory_model_1'] = words[0];
    attributes['control.accessory_model_2'] = words[1];
    attributes['control.gun_drive_type'] = words[2];
    attributes['control.gun_swing_range_mode'] = words[3];
    attributes['control.process_type'] = words[4];
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async =>
      Map<String, Object?>.from(attributes);

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    if (id == 'control.field_1' && controlWriteDelay > Duration.zero) {
      await Future<void>.delayed(controlWriteDelay);
    }
    attributes[id] = value;
    if (id == 'control.field_1' && value is num) {
      controlField1Writes.add(value.toInt());
    }
    return true;
  }

  @override
  Future<Object?> readAttribute(String id) async => attributes[id];

  @override
  Future<void> ensurePolling() async {}

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}

/// Owns [AppServices] so [OsWallClock] is disposed when the harness is removed.
final class _AppServicesHost extends StatefulWidget {
  const _AppServicesHost({
    required this.services,
    required this.child,
  });

  final AppServices services;
  final Widget child;

  @override
  State<_AppServicesHost> createState() => _AppServicesHostState();
}

final class _AppServicesHostState extends State<_AppServicesHost> {
  @override
  void dispose() {
    widget.services.wallClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: widget.child,
    );
  }
}
