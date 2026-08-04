import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_reminder_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';

void main() {
  tearDown(LaserEnableReminderGate.resetForTest);

  final l10n = AppLocalizationsEn();

  test('weld modes use welding nozzle copy and show focus scale', () {
    for (final type in [
      ProcessType.continuousWelding,
      ProcessType.spotWelding,
    ]) {
      expect(
        LaserEnableReminderCopy.nozzleTip(type, l10n),
        contains('welding copper nozzle'),
      );
      expect(
        LaserEnableReminderCopy.nozzleAsset(type),
        ProcessModeAssets.laserReminderNozzleWeld,
      );
      expect(LaserEnableReminderCopy.showsFocusScale(type), isTrue);
    }
  });

  test('hand cut uses cutting nozzle and blanks focus scale', () {
    expect(
      LaserEnableReminderCopy.nozzleTip(ProcessType.handCutting, l10n),
      contains('cutting copper nozzle'),
    );
    expect(
      LaserEnableReminderCopy.nozzleAsset(ProcessType.handCutting),
      ProcessModeAssets.laserReminderNozzleCut,
    );
    expect(
      LaserEnableReminderCopy.showsFocusScale(ProcessType.handCutting),
      isFalse,
    );
  });

  test('clean modes use removal copy and blank focus scale', () {
    for (final type in [
      ProcessType.weldCleaning,
      ProcessType.wideCleaning,
    ]) {
      expect(
        LaserEnableReminderCopy.nozzleTip(type, l10n),
        contains('removed'),
      );
      expect(LaserEnableReminderCopy.showsFocusScale(type), isFalse);
    }
  });

  test('focus scale asset maps signed refs', () {
    expect(
      ProcessModeAssets.laserReminderFocusScale(0),
      'assets/process/laser_reminder/fsr_0.webp',
    );
    expect(
      ProcessModeAssets.laserReminderFocusScale(-3),
      'assets/process/laser_reminder/fsr_n3.webp',
    );
    expect(ProcessModeAssets.laserReminderFocusScale(99), isEmpty);
  });

  test('parseFocusScaleRef defaults invalid to 0', () {
    expect(LaserEnableReminderCopy.parseFocusScaleRef(null), 0);
    expect(LaserEnableReminderCopy.parseFocusScaleRef(''), 0);
    expect(LaserEnableReminderCopy.parseFocusScaleRef('-4'), -4);
    expect(LaserEnableReminderCopy.parseFocusScaleRef('x'), 0);
  });

  test('session gate suppresses independently', () {
    expect(
      LaserEnableReminderGate.isSuppressed(LaserEnableReminderSession.quick),
      isFalse,
    );
    LaserEnableReminderGate.suppress(LaserEnableReminderSession.quick);
    expect(
      LaserEnableReminderGate.isSuppressed(LaserEnableReminderSession.quick),
      isTrue,
    );
    expect(
      LaserEnableReminderGate.isSuppressed(
        LaserEnableReminderSession.engineer,
      ),
      isFalse,
    );
  });
}
