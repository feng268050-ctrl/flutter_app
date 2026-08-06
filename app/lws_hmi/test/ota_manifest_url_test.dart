import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';

void main() {
  late Directory tempDir;
  late String prefsPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ota-manifest-url-');
    prefsPath = '${tempDir.path}/cloud-settings.json';
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  CloudSettingsStore storeWith({
    required bool enabled,
    required CloudEnvironmentTier tier,
  }) {
    File(prefsPath).writeAsStringSync(
      '{"environmentTier":"${tier.wireName}",'
      '"cloudServicesEnabled":$enabled,'
      '"lanEnhancementEnabled":false}\n',
    );
    final store = CloudSettingsStore(preferencePath: prefsPath);
    store.warmRead();
    return store;
  }

  test('returns null when cloud services disabled', () {
    final store = storeWith(enabled: false, tier: CloudEnvironmentTier.test);
    expect(
      OtaManifestUrl.resolve(
        cloudSettings: store,
        pinnedApiBase: Uri.parse('https://api-test.example'),
      ),
      isNull,
    );
  });

  test('returns null when API origin not pinned', () {
    final store = storeWith(enabled: true, tier: CloudEnvironmentTier.test);
    expect(
      OtaManifestUrl.resolve(cloudSettings: store, pinnedApiBase: null),
      isNull,
    );
  });

  test('test/dev tier uses staging.json under /r2/lws-hmi/', () {
    final store = storeWith(enabled: true, tier: CloudEnvironmentTier.test);
    expect(
      OtaManifestUrl.resolve(
        cloudSettings: store,
        pinnedApiBase: Uri.parse('https://api-test.lasercyber.workers.dev'),
      ),
      'https://api-test.lasercyber.workers.dev/r2/lws-hmi/staging.json',
    );

    final dev = storeWith(enabled: true, tier: CloudEnvironmentTier.dev);
    expect(
      OtaManifestUrl.resolve(
        cloudSettings: dev,
        pinnedApiBase: Uri.parse('http://10.0.2.2:8787'),
      ),
      'http://10.0.2.2:8787/r2/lws-hmi/staging.json',
    );
  });

  test('prod tier uses release.json under /r2/', () {
    final store = storeWith(enabled: true, tier: CloudEnvironmentTier.prod);
    expect(
      OtaManifestUrl.resolve(
        cloudSettings: store,
        pinnedApiBase: Uri.parse('https://api-prod.lasercyber.workers.dev'),
      ),
      'https://api-prod.lasercyber.workers.dev/r2/lws-hmi/release.json',
    );
  });

  test('resolveView keeps /view/ path for when Worker allowlists HMI', () {
    final store = storeWith(enabled: true, tier: CloudEnvironmentTier.test);
    expect(
      OtaManifestUrl.resolveView(
        cloudSettings: store,
        pinnedApiBase: Uri.parse('https://api-prod.lasercyber.workers.dev'),
      ),
      'https://api-prod.lasercyber.workers.dev/view/lws-hmi/staging.json',
    );
  });

  test('preserves path prefix on pinned base', () {
    final store = storeWith(enabled: true, tier: CloudEnvironmentTier.test);
    expect(
      OtaManifestUrl.resolve(
        cloudSettings: store,
        pinnedApiBase: Uri.parse('https://lasercyber.hyurl.com/test'),
      ),
      'https://lasercyber.hyurl.com/test/r2/lws-hmi/staging.json',
    );
  });
}
