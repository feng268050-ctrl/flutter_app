import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/laser_enable_region_frost.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';

void main() {
  setUp(LaserEnableRegionFrost.debugResetCaptureQueue);

  testWidgets('passes child through when disarmed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LaserEnableRegionFrost(
            armed: false,
            child: Text('visible'),
          ),
        ),
      ),
    );
    expect(find.text('visible'), findsOneWidget);
    expect(find.byKey(const ValueKey('laser-enable-region-frost')), findsNothing);
  });

  testWidgets('arms with immediate lock + veil before snapshot settles',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 48,
              child: LaserEnableRegionFrost(
                armed: true,
                child: TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('tap-me'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // First frame: AbsorbPointer + tint already up (no wait for toImage).
    await tester.pump();
    expect(find.byKey(const ValueKey('laser-enable-region-frost')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('laser-enable-region-frost')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(tapped, isFalse);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('tap-me'), findsOneWidget);
  });

  testWidgets('restores live child when disarmed after capture', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 48,
              child: LaserEnableRegionFrost(
                armed: true,
                child: const Text('wheel'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 48,
              child: LaserEnableRegionFrost(
                armed: false,
                child: Text('wheel'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('wheel'), findsOneWidget);
    expect(find.byKey(const ValueKey('laser-enable-region-frost')), findsNothing);
  });

  test('mist uses BlurUtils radius 15 and stays translucent', () {
    expect(LaserEnableRegionFrost.sigma, 15);
    expect(LaserEnableRegionFrost.tint.alpha, lessThan(0x50));
  });

  test('disable failure copy is distinct from enable writeFailed', () {
    final l10n = AppLocalizationsEn();
    expect(
      DeviceControlFeedbackCopy.messageForDisable(
        l10n,
        LaserEnableBlockReason.writeFailed,
      ),
      DeviceControlFeedbackCopy.endOfWorkFailed(l10n),
    );
    expect(
      DeviceControlFeedbackCopy.messageForDisable(
        l10n,
        LaserEnableBlockReason.busy,
      ),
      LaserEnableBlockReason.busy.localizedMessage(l10n),
    );
    expect(
      LaserEnableBlockReason.writeFailed.localizedMessage(l10n),
      isNot(DeviceControlFeedbackCopy.endOfWorkFailed(l10n)),
    );
  });
}
