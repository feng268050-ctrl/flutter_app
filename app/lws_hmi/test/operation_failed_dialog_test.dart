import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_theme.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  tearDown(OperationFailedDialogHost.debugReset);

  testWidgets('safety clear auto-dismisses matching key-off tip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en', 'US'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                key: const ValueKey('open-tip'),
                onPressed: () {
                  OperationFailedDialogHost.show(
                    context,
                    message: 'Key switch is off',
                    safetyEvent: DeviceControlSafetyEvent.keySwitchOff,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-tip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('operation-failed-dialog')), findsOneWidget);
    expect(OperationFailedDialogHost.isShowing, isTrue);
    expect(
      OperationFailedDialogHost.shownFor,
      DeviceControlSafetyEvent.keySwitchOff,
    );

    // Unrelated clear must not dismiss key-off tip.
    OperationFailedDialogHost.dismissForSafetyClear(
      DeviceControlSafetyEvent.emergencyStopCleared,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('operation-failed-dialog')), findsOneWidget);

    OperationFailedDialogHost.dismissForSafetyClear(
      DeviceControlSafetyEvent.keySwitchRestored,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('operation-failed-dialog')), findsNothing);
    expect(OperationFailedDialogHost.isShowing, isFalse);
  });
}
