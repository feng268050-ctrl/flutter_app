import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/app_navigation.dart';
import 'package:lws_hmi/app/app_services.dart';
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

  AppServices testServices() => AppServices(
        boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
        sysInfo: StubSysInfo(),
        modbusClient: _UnusedModbus(),
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
            interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
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
  }) {
    return _AppServicesHost(
      services: testServices(),
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
      CyberBorderGradientCenter.topBottom,
    );
    expect(resetButton.strokeWidth, 1.5);
    expect(resetButton.borderGradientColors?.first.alpha, greaterThan(0x77));

    expect(find.byKey(const ValueKey('engineer-param-process.laser_power')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('engineer-ramp-accordion')), findsOneWidget);

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
      ProcessModeDimens.engineerTabLabelSize,
    );
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

  testWidgets('Reset to Default shows toast, not success dialog', (tester) async {
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

  testWidgets(
      'CW session cache restore does not auto-apply (lws-ui isInit)',
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
  _RecordingModbus() {
    for (final spec in ProcessParameterCatalog.specs) {
      attributes[spec.key] = 0.0;
    }
    attributes['control.process_type'] = 0;
  }

  final Map<String, Object?> attributes = {};
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
  Future<Map<String, Object?>> readGroup(String groupId) async =>
      Map<String, Object?>.from(attributes);

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    attributes[id] = value;
    return true;
  }

  @override
  Future<Object?> readAttribute(String id) async => attributes[id];
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
