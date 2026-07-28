import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/infrastructure/sqlite_process_library_repository.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_library/presentation/quick_mode_page.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_carry.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_value_pick.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(QuickModeSelectionCarry.clear);

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  Future<ProcessLibraryController> seedController() async {
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
        rowCount: 3,
      ),
      presets: [
        _quick(
          uuid: 'ss-1-1',
          gear: 1,
          thickness: 1,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          uuid: 'ss-2-2',
          gear: 2,
          thickness: 2,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          uuid: 'cs-1-1',
          gear: 1,
          thickness: 1,
          material: MaterialType.carbonSteel,
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
        modbus: _UnusedModbus(),
        interlockFailure: () async => ProcessApplyFailure.unsafeMachineState,
      ),
    );
    addTearDown(controller.close);
    await controller.initialize();
    return controller;
  }

  testWidgets('QuickModePage shows pickers and laser dashboard',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const QuickModePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('quick-mode-material-wheel')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('quick-mode-gear-pick')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-mode-dimension-pick')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('quick-mode-more-parameters')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('quick-mode-laser-dashboard')),
        findsOneWidget);
    expect(find.text('Stainless Steel'), findsWidgets);

    final dashboardCenter = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-laser-dashboard')),
    );
    final modeCenter = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-process-wheel')),
    );
    final materialCenter = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-material-wheel')),
    );
    final gearCenter = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-gear-pick')),
    );
    final dimensionCenter = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-dimension-pick')),
    );
    expect(modeCenter.dy, closeTo(dashboardCenter.dy + ProcessModeDimens.quickSelectorNudgeY, 1));
    expect(
      materialCenter.dy,
      closeTo(
        dashboardCenter.dy + ProcessModeDimens.materialVerticalOffset,
        1,
      ),
    );
    expect(
      gearCenter.dy,
      closeTo(
        dashboardCenter.dy + ProcessModeDimens.pickerVerticalFromPageCenter,
        1,
      ),
    );
    expect(
      dimensionCenter.dy,
      closeTo(
        dashboardCenter.dy + ProcessModeDimens.pickerVerticalFromPageCenter,
        1,
      ),
    );
    // Scale image ↔ dashboard circle center; value accent ↔ mode / material.
    final accents = find.byKey(const ValueKey('quick-mode-value-pick-accent'));
    expect(accents, findsNWidgets(2));
    final gearAccent = tester.getCenter(accents.at(0));
    final thicknessAccent = tester.getCenter(accents.at(1));
    final selectionMidlineY =
        dashboardCenter.dy + ProcessModeDimens.quickSelectorNudgeY;
    expect(gearAccent.dy, closeTo(selectionMidlineY, 3));
    expect(thicknessAccent.dy, closeTo(selectionMidlineY, 3));
    expect(modeCenter.dy, closeTo(selectionMidlineY, 1));
    expect(materialCenter.dy, closeTo(selectionMidlineY, 2));
    final scaleLeft = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-scale-left')),
    );
    final scaleRight = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-scale-right')),
    );
    expect(scaleLeft.dy, closeTo(dashboardCenter.dy, 3));
    expect(scaleRight.dy, closeTo(dashboardCenter.dy, 3));
    // Pick placement tracks accent / value slot vs thin bright ring.
    final dashboardSize = tester.getSize(
      find.byKey(const ValueKey('quick-mode-laser-dashboard')),
    );
    final dashScale =
        dashboardSize.width / ProcessModeDimens.dashboardDesignSize;
    final liveHighlightR = dashboardSize.width / 2 -
        (ProcessModeDimens.dashboardOuterStrokeDesign * dashScale) / 2 -
        (ProcessModeDimens.dashboardLineStrokeDesign * dashScale) / 2;
    expect(
      gearCenter.dx,
      closeTo(
        dashboardCenter.dx +
            QuickModePickerDimens.gearPickCenterFromPageCenter(liveHighlightR),
        4,
      ),
    );
    expect(
      dimensionCenter.dx,
      closeTo(
        dashboardCenter.dx +
            QuickModePickerDimens.thicknessPickCenterFromPageCenter(
              liveHighlightR,
            ),
        4,
      ),
    );
    // Accent midline sits on the value-wheel center (same X as pick math).
    final gearValueX = dashboardCenter.dx +
        QuickModePickerDimens.gearValueCenterFromPageCenter(liveHighlightR);
    expect(gearAccent.dx, closeTo(gearValueX, 4));
  });

  testWidgets('tap switches gear thickness material and mode', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const QuickModePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final gear = find.byKey(const ValueKey('quick-mode-gear-pick'));
    await tester.drag(gear, Offset(0, -QuickModePickerDimens.itemHeight));
    await tester.pump(const Duration(milliseconds: 500));

    final material = find.byKey(const ValueKey('quick-mode-material-wheel'));
    await tester.drag(material, Offset(0, -QuickModePickerDimens.itemHeight));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Carbon Steel'), findsWidgets);

    await tester.tap(find.text('Spot Welding', skipOffstage: false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Spot Welding'), findsWidgets);
  });

  testWidgets('More Parameters navigates with draft uuid', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const QuickModePage(),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.engineerMode) {
            final args = settings.arguments;
            if (args is EngineerModeRouteArgs) {
              return MaterialPageRoute<void>(
                builder: (_) => ProcessLibraryScope(
                  controller: controller,
                  child: EngineerModePage(
                    initialProcessType: args.processType,
                    initialPresetUuid: args.presetUuid,
                  ),
                ),
                settings: settings,
              );
            }
          }
          return null;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey('quick-mode-more-parameters')));
    await tester.pump();
    expect(find.byKey(const ValueKey('engineer-mode-entry-tips')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('engineer-mode-entry-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.byKey(const ValueKey('engineer-mode-draft-uuid')), findsOneWidget);
  });

  testWidgets('CNC hides pickers and more parameters', (tester) async {
    await setDesignSurface(tester);
    final controller = await seedController();
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessLibraryScope(
          controller: controller,
          child: const QuickModePage(),
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
    expect(
        find.byKey(const ValueKey('quick-mode-material-wheel')), findsNothing);
    expect(
        find.byKey(const ValueKey('quick-mode-more-parameters')), findsNothing);
    expect(find.byKey(const ValueKey('quick-mode-record-work')), findsNothing);
  });
}

ProcessPreset _quick({
  required String uuid,
  required int gear,
  required double thickness,
  required MaterialType material,
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
      'process.laser_power': 40,
      'process.laser_frequency': 1000,
      'process.laser_duty_cycle': 50,
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
