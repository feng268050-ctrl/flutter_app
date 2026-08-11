import 'dart:io';

import 'package:cyber_hal/network/cloud_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CloudEnvironmentPrefs defaults and round-trip', () async {
    final dir = await Directory.systemTemp.createTemp('cloud-env-');
    addTearDown(() => dir.delete(recursive: true));
    final conf = '${dir.path}/cloud.conf';

    expect(
      await CloudEnvironmentPrefs.read(conf),
      CloudEnvironmentTier.prod,
    );

    await CloudEnvironmentPrefs.write(CloudEnvironmentTier.test, conf);
    expect(await CloudEnvironmentPrefs.read(conf), CloudEnvironmentTier.test);
    expect(
      File(conf).readAsStringSync(),
      contains('environment_tier=test'),
    );
  });

  test('migrates environmentTier from legacy HMI JSON once', () async {
    final dir = await Directory.systemTemp.createTemp('cloud-env-mig-');
    addTearDown(() => dir.delete(recursive: true));
    final conf = '${dir.path}/cloud.conf';
    final legacy = '${dir.path}/cloud-settings.json';
    await File(legacy).writeAsString('{"environmentTier":"test"}\n');

    final tier = await CloudEnvironmentPrefs.readOrMigrate(
      conf: conf,
      legacyJson: legacy,
    );
    expect(tier, CloudEnvironmentTier.test);
    expect(await File(conf).exists(), isTrue);
    expect(await CloudEnvironmentPrefs.read(conf), CloudEnvironmentTier.test);

    // Conf wins even if legacy changes.
    await File(legacy).writeAsString('{"environmentTier":"prod"}\n');
    expect(
      await CloudEnvironmentPrefs.readOrMigrate(
        conf: conf,
        legacyJson: legacy,
      ),
      CloudEnvironmentTier.test,
    );
  });

  test('legacy dev maps to prod', () {
    expect(
      CloudEnvironmentTierCodec.parse('dev'),
      CloudEnvironmentTier.prod,
    );
  });
}
