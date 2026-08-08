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

    test('parses publish-shaped channel JSON with url', () {
      final manifest = OtaManifest.fromJson(<String, dynamic>{
        'version': '1.0.41',
        'filename': 'v1.0.41.tar.gz',
        'published_at': '2026-08-06T08:00:00Z',
        'url': 'https://cdn.example/lws-hmi/v1.0.41.tar.gz',
      });

      expect(manifest.version, '1.0.41');
      expect(
        manifest.packageUrl,
        'https://cdn.example/lws-hmi/v1.0.41.tar.gz',
      );
      expect(
        manifest.sigUrlResolved,
        'https://cdn.example/lws-hmi/v1.0.41.tar.gz.sig',
      );
      expect(manifest.sha512, isNull);
    });

    test('package_url takes precedence over url', () {
      final manifest = OtaManifest.fromJson(<String, dynamic>{
        'version': '1.2.0',
        'package_url': 'https://cdn.example/from-package.tar.gz',
        'url': 'https://cdn.example/from-url.tar.gz',
      });

      expect(manifest.packageUrl, 'https://cdn.example/from-package.tar.gz');
    });

    test('missing both url and package_url throws', () {
      expect(
        () => OtaManifest.fromJson(<String, dynamic>{
          'version': '1.0.0',
          'filename': 'v1.0.0.tar.gz',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses optional title and content', () {
      final manifest = OtaManifest.fromJson(<String, dynamic>{
        'version': 'v1.2.0',
        'url': 'https://cdn.example/pkg.tar.gz',
        'title': 'Big release',
        'content': 'Notes here',
      });
      expect(manifest.displayTitle, 'Big release');
      expect(manifest.content, 'Notes here');
      expect(OtaManifest.coreVersion('v1.0.40-beta'), '1.0.40');
    });
  });
}
