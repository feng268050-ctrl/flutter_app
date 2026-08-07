import 'package:cyber_hal/output/load_profile.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/load_profile_controller.dart';
import 'package:lws_hmi/features/settings/application/load_profile_scope.dart';
import 'package:lws_hmi/features/settings/presentation/pages/power_mode_settings_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  testWidgets('PowerModeSettingsPage selects balanced via HAL', (tester) async {
    final backend = StubLoadProfile();
    final controller = LoadProfileController(backend: backend);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: LoadProfileScope(
          controller: controller,
          child: const PowerModeSettingsPage(),
        ),
      ),
    );
    // SettingsScaffold blur plate never settles; use finite pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Performance'), findsWidgets);
    expect(find.text('Balanced'), findsWidgets);

    await tester.tap(find.text('Balanced').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.mode, LoadProfileMode.balanced);
    expect(await backend.getMode(), LoadProfileMode.balanced);
  });
}
