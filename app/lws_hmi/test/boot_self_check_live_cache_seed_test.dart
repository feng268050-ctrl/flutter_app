import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_live_cache_seed.dart';

void main() {
  tearDown(BootSelfCheckLiveCacheSeed.resetForTest);

  test('offer then take consumes once', () {
    BootSelfCheckLiveCacheSeed.offer(
      status: const {'device.type': 1},
      data: const {'telemetry.gun_motor_temp': 25},
    );
    expect(BootSelfCheckLiveCacheSeed.takeStatus(), {'device.type': 1});
    expect(BootSelfCheckLiveCacheSeed.takeData(), {
      'telemetry.gun_motor_temp': 25,
    });
    expect(BootSelfCheckLiveCacheSeed.takeStatus(), isNull);
    expect(BootSelfCheckLiveCacheSeed.takeData(), isNull);
  });

  test('empty maps are not offered', () {
    BootSelfCheckLiveCacheSeed.offer(status: const {}, data: const {});
    expect(BootSelfCheckLiveCacheSeed.takeStatus(), isNull);
    expect(BootSelfCheckLiveCacheSeed.takeData(), isNull);
  });
}
