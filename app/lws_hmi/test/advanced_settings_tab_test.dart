import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_thresholds_controller.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

class _OfflineModbus extends ModbusRtuClient {
  _OfflineModbus() : super();

  @override
  Future<void> ensurePolling() async {}

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<Object?> readAttribute(String id) async => null;

  @override
  Future<bool> writeAttribute(String id, Object? value) async => false;

  @override
  Future<bool> writeGroup(
    String groupId,
    Map<String, Object?> values,
  ) async =>
      false;

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async {
    return const Stream<List<ModbusAttributeChange>>.empty();
  }
}

void main() {
  testWidgets('Advanced tab shows Cyber switches for AI and dangerous',
      (tester) async {
    final path =
        '${Directory.systemTemp.path}/adv-settings-tab-${pid}.json';
    final store = AdvancedSettingsStore(preferencePath: path);
    store.warmRead();
    final ai = AiAssistanceSettings(store);
    final dangerous = DangerousOperationsSettings(store);
    final services = AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "board_id": "sim",
  "display_name": "sim",
  "capabilities": ["sysInfo"],
  "net_roles": {},
  "configs": {},
  "storage_mounts": ["/"],
  "helpers": {}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: _OfflineModbus(),
    );
    final thresholds = AdvancedSettingsThresholdsController(
      store: store,
      services: services,
    );
    thresholds.warmFromStore();

    addTearDown(() async {
      ai.dispose();
      dangerous.dispose();
      thresholds.dispose();
      store.dispose();
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
      await tester.binding.setSurfaceSize(null);
    });

    await tester.binding.setSurfaceSize(const Size(1280, 5000));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdvancedSettingsScope(
          store: store,
          aiAssistance: ai,
          dangerousOperations: dangerous,
          thresholds: thresholds,
          child: const Scaffold(body: AdvancedSettingsTab()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('OFFSET & CORRECTION'), findsOneWidget);
    expect(find.text('POWER THRESHOLDS'), findsOneWidget);
    expect(find.text('TEMPERATURE THRESHOLDS'), findsOneWidget);
    expect(find.text('AI ASSISTANCE'), findsOneWidget);
    expect(find.text('OVERRIDE SAFEGUARDS'), findsOneWidget);
    expect(find.text('Zero Offset'), findsOneWidget);
    expect(find.text('Lens Contamination Detection'), findsOneWidget);
    expect(find.text('Keep Laser On During Alarms'), findsOneWidget);
    expect(find.byType(CyberScaledSlider), findsWidgets);
    expect(find.byType(CyberSwitch), findsNWidgets(7));

    // Cancel OsWallClock before Flutter's post-test timer invariant.
    services.wallClock.dispose();
  });
}
