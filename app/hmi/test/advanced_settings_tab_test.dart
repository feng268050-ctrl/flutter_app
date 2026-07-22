import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/ai_assistance_settings.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/presentation/tabs/advanced_settings_tab.dart';

void main() {
  testWidgets('Advanced tab shows Cyber switches for AI and dangerous',
      (tester) async {
    final path =
        '${Directory.systemTemp.path}/adv-settings-tab-${pid}.json';
    final store = AdvancedSettingsStore(preferencePath: path);
    store.warmRead();
    final ai = AiAssistanceSettings(store);
    final dangerous = DangerousOperationsSettings(store);

    addTearDown(() async {
      ai.dispose();
      dangerous.dispose();
      store.dispose();
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
      await tester.binding.setSurfaceSize(null);
    });

    // Tall surface so lazy ListView builds threshold + AI + Dangerous sections.
    await tester.binding.setSurfaceSize(const Size(1280, 5000));
    await tester.pumpWidget(
      MaterialApp(
        home: AdvancedSettingsScope(
          store: store,
          aiAssistance: ai,
          dangerousOperations: dangerous,
          child: const Scaffold(body: AdvancedSettingsTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('OFFSET & CORRECTION'), findsOneWidget);
    expect(find.text('POWER THRESHOLDS'), findsOneWidget);
    expect(find.text('TEMPERATURE THRESHOLDS'), findsOneWidget);
    expect(find.text('AI ASSISTANCE'), findsOneWidget);
    expect(find.text('DANGEROUS OPERATIONS'), findsOneWidget);
    expect(find.text('Zero Offset'), findsOneWidget);
    expect(find.text('Lens Contamination Detection'), findsOneWidget);
    expect(find.text('Keep Laser On while Alarmed'), findsOneWidget);
    expect(find.byType(CyberScaledSlider), findsWidgets);
    expect(find.byType(CyberSwitch), findsNWidgets(7));
  });
}
