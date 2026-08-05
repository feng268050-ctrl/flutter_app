import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

void main() {
  group('OtaManifest', () {
    test('parses required and optional fields', () {
      final manifest = OtaManifest.fromJson(<String, dynamic>{
        'version': '2.0.0',
        'package_url': 'https://cdn.example/ota.tar.gz',
        'sig_url': 'https://cdn.example/ota.tar.gz.sig',
        'sha512': 'abc',
      });

      expect(manifest.version, '2.0.0');
      expect(manifest.packageUrl, 'https://cdn.example/ota.tar.gz');
      expect(manifest.sigUrl, 'https://cdn.example/ota.tar.gz.sig');
      expect(manifest.sha512, 'abc');
      expect(manifest.sigUrlResolved, 'https://cdn.example/ota.tar.gz.sig');
    });

    test('sigUrlResolved defaults to package_url + .sig', () {
      final manifest = OtaManifest.fromJson(<String, dynamic>{
        'version': '1.0.0',
        'package_url': 'https://cdn.example/pkg.tar.gz',
      });

      expect(manifest.sigUrlResolved, 'https://cdn.example/pkg.tar.gz.sig');
    });
  });
}
