import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/application/cnc_session_controller.dart';
import 'package:lws_hmi/features/process_mode/presentation/cnc_connection_guide.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('step labels left-align wrapped lines with step number',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: CncConnectionGuide(
              linkStatus: CncLinkStatus.failed,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final step in [
      '1. Verify the RS485 connection.',
      '2. Verify the cutting nozzle sensor cable.',
      '3. Confirm that the welding gun and fixture are securely connected.',
    ]) {
      final text = tester.widget<Text>(find.text(step));
      expect(
        text.textAlign,
        TextAlign.start,
        reason: '$step should left-align each wrapped line with the number',
      );
    }
  });
}
