import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/hmi_app_ota/infrastructure/hmi_app_manifest_url.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';

void main() {
  test('default resolve is CDN release.json', () {
    expect(
      OtaManifestUrl.resolve(),
      'https://cdn.lasercyber.com/lws-hmi/release.json',
    );
  });

  test('custom artifact', () {
    expect(
      OtaManifestUrl.resolve(artifact: 'cnc_hmi'),
      'https://cdn.lasercyber.com/cnc_hmi/release.json',
    );
    expect(
      OtaManifestUrl.resolve(artifact: '/cnc-hmi/'),
      'https://cdn.lasercyber.com/cnc-hmi/release.json',
    );
  });

  test('HMI app channel is CDN app/release.json', () {
    expect(
      HmiAppManifestUrl.resolve(),
      'https://cdn.lasercyber.com/lws-hmi/app/release.json',
    );
    expect(
      HmiAppManifestUrl.resolve(artifact: 'cnc_hmi'),
      'https://cdn.lasercyber.com/cnc_hmi/app/release.json',
    );
  });
}
