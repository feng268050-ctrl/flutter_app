import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/bundled_firmware/application/control_board_upgrade_checker.dart';

void main() {
  test('control-board checker finds newer SW', () async {
    final checker = ControlBoardUpgradeChecker(
      deviceHw: 1000,
      deviceSw: 1012,
      assetFileNames: const [
        'LSW01H1000S1013.bin',
        'LSW01H1001S1099.bin',
      ],
    );
    final result = await checker.check(currentVersion: '1012');
    expect(result, isA<UpgradeCheckAvailable>());
    final offer = (result as UpgradeCheckAvailable).offer;
    expect(offer.version, '1013');
    expect(offer.channel, UpgradeChannel.controlBoard);
  });

  test('host force policy skips version gate in checker', () async {
    final checker = ControlBoardUpgradeChecker(
      deviceHw: 1000,
      deviceSw: 1012,
      assetFileNames: const ['LSW01H1000S1013.bin'],
    );
    final result = await checker.check(
      currentVersion: '1012',
      policy: UpgradePolicy.hostForce,
    );
    expect(result, isA<UpgradeCheckUnavailable>());
  });

  test('same SW is up to date', () async {
    final checker = ControlBoardUpgradeChecker(
      deviceHw: 1000,
      deviceSw: 1013,
      assetFileNames: const ['LSW01H1000S1013.bin'],
    );
    final result = await checker.check(currentVersion: '1013');
    expect(result, isA<UpgradeCheckUpToDate>());
  });
}
