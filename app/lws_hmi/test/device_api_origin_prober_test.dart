import 'dart:async';

import 'package:cyber_hal/network/cloud_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_prober.dart';

void main() {
  test('probe pins first success among concurrent candidates (lws-ui race)',
      () async {
    final delays = <String, Duration>{
      'api-test.lasercyber.workers.dev': const Duration(milliseconds: 80),
      'lasercyber.hyurl.com': const Duration(milliseconds: 5),
    };
    final prober = DeviceApiOriginProber(
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
    final prober = DeviceApiOriginProber(
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
      DeviceApiOriginProber.defaultTimeout,
      const Duration(seconds: 2),
    );
  });

  test('probe falls back when only secondary is reachable', () async {
    final prober = DeviceApiOriginProber(
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
}
