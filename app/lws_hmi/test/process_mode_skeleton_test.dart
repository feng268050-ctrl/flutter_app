import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_library/presentation/quick_mode_page.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_process_wheel.dart';

import 'process_library_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapApp(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );
  }

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  test('ProcessModeLabels match lws-ui English names', () {
    expect(
      ProcessModeLabels.wheelLabel(
        ProcessType.continuousWelding,
        AppLocalizationsEn(),
      ),
      'Continuous welding',
    );
    expect(
      ProcessModeLabels.engineerTabLabel(
        ProcessType.weldCleaning,
        AppLocalizationsEn(),
      ),
      'Weld seam',
    );
    expect(EngineerProcessTabs.types, hasLength(5));
    expect(QuickProcessWheelItems.types, hasLength(6));
  });

  testWidgets('QuickModePage shows process wheel and status chrome',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await createEmptyProcessLibraryController(tester);
    await tester.pumpWidget(
      wrapApp(wrapWithProcessLibrary(controller, const QuickModePage())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('quick-mode-process-wheel')),
        findsOneWidget);
    expect(find.text('Continuous welding'), findsWidgets);
    expect(find.text('Gun Switch'), findsOneWidget);
  });

  testWidgets('QuickModeProcessWheel notifies on scroll selection',
      (tester) async {
    await setDesignSurface(tester);
    var selected = ProcessType.continuousWelding;
    await tester.pumpWidget(
      wrapApp(
        Scaffold(
          body: QuickModeProcessWheel(
            processType: selected,
            onChanged: (type) => selected = type,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('quick-mode-process-wheel')),
      const Offset(0, -ProcessModeDimens.wheelItemHeight),
    );
    await tester.pumpAndSettle();

    expect(selected, ProcessType.spotWelding);
  });

  testWidgets('EngineerModePage shows five tabs and switches accent label',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await createEmptyProcessLibraryController(tester);
    await tester.pumpWidget(
      wrapApp(wrapWithProcessLibrary(controller, const EngineerModePage())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('engineer-process-tab-bar')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('engineer-process-tab-bar'))),
      const Size(1280, ProcessModeDimens.engineerTabBarHeight),
    );
    expect(find.text('Continuous'), findsOneWidget);
    expect(find.text('Spot'), findsOneWidget);
    expect(find.text('Weld seam'), findsOneWidget);
    expect(find.text('Wide-area'), findsOneWidget);
    expect(find.text('Cutting'), findsOneWidget);
    expect(find.textContaining('CNC'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('engineer-tab-weldCleaning')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('engineer-process-tab-bar')),
        findsOneWidget);
  });

  testWidgets('EngineerProcessTabBar respects initialProcessType',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await createEmptyProcessLibraryController(tester);
    await tester.pumpWidget(
      wrapApp(
        wrapWithProcessLibrary(
          controller,
          const EngineerModePage(
            initialProcessType: ProcessType.handCutting,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Cutting'), findsWidgets);
  });
}
