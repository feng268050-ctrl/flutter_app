import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/network/cloud_environment.dart';
import 'package:cyber_hal/network/cloud_origin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudApiOriginConfig', () {
    test('maps https pin to wss device URL with sn', () {
      final uri = CloudApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: Uri.parse('https://api-test.lasercyber.workers.dev'),
        deviceSn: 'ABC123',
      );
      expect(uri.scheme, 'wss');
      expect(uri.host, 'api-test.lasercyber.workers.dev');
      expect(uri.path, '/ws/device');
      expect(uri.queryParameters['sn'], 'ABC123');
    });

    test('preserves path prefix on http pin', () {
      final uri = CloudApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: Uri.parse('http://47.86.53.176:8080/prod'),
        deviceSn: 'X',
      );
      expect(uri.scheme, 'ws');
      expect(uri.path, '/prod/ws/device');
    });

    test('default candidate lists include workers + hyurl', () {
      final test = CloudApiOriginConfig.orderedCandidateBases(
          CloudEnvironmentTier.test);
      final prod = CloudApiOriginConfig.orderedCandidateBases(
          CloudEnvironmentTier.prod);
      expect(test.map((u) => u.toString()), [
        'https://api-test.lasercyber.workers.dev',
        'https://lasercyber.hyurl.com/test',
      ]);
      expect(prod.map((u) => u.toString()), [
        'https://api-prod.lasercyber.workers.dev',
        'https://lasercyber.hyurl.com/prod',
      ]);
    });
  });

  group('CloudApiOriginProber', () {
    test('pins first success among concurrent candidates', () async {
      final delays = <String, Duration>{
        'api-test.lasercyber.workers.dev': const Duration(milliseconds: 80),
        'lasercyber.hyurl.com': const Duration(milliseconds: 5),
      };
      final dir = await Directory.systemTemp.createTemp('origin-race-');
      addTearDown(() => dir.delete(recursive: true));
      final prober = CloudApiOriginProber(
        pinPath: '${dir.path}/pin',
        probe: (base, {required timeout}) async {
          await Future<void>.delayed(delays[base.host] ?? Duration.zero);
          return true;
        },
      );
      final sw = Stopwatch()..start();
      final pin = await prober.probe(CloudEnvironmentTier.test);
      expect(pin?.toString(), 'https://lasercyber.hyurl.com/test');
      expect(sw.elapsedMilliseconds, lessThan(60));
    });

    test('all-fail probe round ends within default 2s budget', () async {
      final dir = await Directory.systemTemp.createTemp('origin-fail-');
      addTearDown(() => dir.delete(recursive: true));
      final prober = CloudApiOriginProber(
        pinPath: '${dir.path}/pin',
        probe: (base, {required timeout}) async {
          await Future<void>.delayed(const Duration(seconds: 10));
          return true;
        },
      );
      final sw = Stopwatch()..start();
      final pin = await prober.probe(CloudEnvironmentTier.test);
      expect(pin, isNull);
      expect(sw.elapsedMilliseconds, lessThan(2500));
      expect(
        CloudApiOriginProber.defaultTimeout,
        const Duration(seconds: 2),
      );
    });

    test('falls back when only secondary is reachable', () async {
      final prober = CloudApiOriginProber(
        pinPath: '${Directory.systemTemp.path}/lws-origin-pin-fallback',
        probe: (base, {required timeout}) async {
          if (base.host.contains('workers.dev')) {
            throw TimeoutException('primary down');
          }
          return true;
        },
      );
      final pin = await prober.probe(CloudEnvironmentTier.test);
      expect(pin?.toString(), 'https://lasercyber.hyurl.com/test');
    });

    test('custom catalog is used', () async {
      final dir = await Directory.systemTemp.createTemp('origin-custom-');
      addTearDown(() => dir.delete(recursive: true));
      final config = CloudApiOriginConfig(
        testBases: const ['https://only.test.example'],
        prodBases: const ['https://only.prod.example'],
      );
      final prober = CloudApiOriginProber(
        config: config,
        pinPath: '${dir.path}/pin',
        probe: (base, {required timeout}) async => true,
      );
      final pin = await prober.probe(CloudEnvironmentTier.test);
      expect(pin?.toString(), 'https://only.test.example');
    });

    test('boot pin is reused across prober instances', () async {
      final dir = await Directory.systemTemp.createTemp('origin-pin-');
      addTearDown(() => dir.delete(recursive: true));
      final pinPath = '${dir.path}/cloud-origin.pin';
      var probes = 0;
      final a = CloudApiOriginProber(
        pinPath: pinPath,
        probe: (base, {required timeout}) async {
          probes++;
          return true;
        },
      );
      final first = await a.probe(CloudEnvironmentTier.test);
      expect(first?.toString(), contains('api-test'));
      expect(probes, greaterThan(0));

      final b = CloudApiOriginProber(
        pinPath: pinPath,
        probe: (base, {required timeout}) async {
          probes++;
          fail('should not probe when boot pin matches');
        },
      );
      final second = await b.probe(CloudEnvironmentTier.test);
      expect(second, first);
      expect(File(pinPath).readAsStringSync(), contains('environment_tier=test'));
    });

    test('clearPin removes boot pin; tier mismatch skips cache', () async {
      final dir = await Directory.systemTemp.createTemp('origin-pin-');
      addTearDown(() => dir.delete(recursive: true));
      final pinPath = '${dir.path}/cloud-origin.pin';
      final a = CloudApiOriginProber(
        pinPath: pinPath,
        probe: (base, {required timeout}) async => true,
      );
      await a.probe(CloudEnvironmentTier.test);
      a.clearPin();
      expect(File(pinPath).existsSync(), isFalse);

      await File(pinPath).writeAsString(
        'environment_tier=prod\npinned_origin=https://stale.example\n',
      );
      var probed = false;
      final b = CloudApiOriginProber(
        pinPath: pinPath,
        probe: (base, {required timeout}) async {
          probed = true;
          return true;
        },
      );
      final pin = await b.probe(CloudEnvironmentTier.test);
      expect(probed, isTrue);
      expect(pin?.host, isNot(equals('stale.example')));
    });
  });
}
