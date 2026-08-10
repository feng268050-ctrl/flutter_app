import 'package:cyber_hal/output/load_profile.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/load_profile_controller.dart';

void main() {
  test('LoadProfileController defaults to performance before load', () {
    final c = LoadProfileController(backend: StubLoadProfile());
    expect(c.mode, LoadProfileMode.performance);
    expect(c.reduceDecorativeMotion, isFalse);
    expect(c.snapPageTransitions, isFalse);
    expect(c.disableAnimations, isFalse);
  });

  test('LoadProfileController load + setMode updates paint policy', () async {
    final backend = StubLoadProfile(initial: LoadProfileMode.balanced);
    final c = LoadProfileController(backend: backend);
    await c.load();
    expect(c.mode, LoadProfileMode.balanced);
    expect(c.reduceDecorativeMotion, isTrue);
    expect(c.snapPageTransitions, isTrue);
    expect(c.disableAnimations, isTrue);

    await c.setMode(LoadProfileMode.performance);
    expect(c.mode, LoadProfileMode.performance);
    expect(c.reduceDecorativeMotion, isFalse);
    expect(await backend.getMode(), LoadProfileMode.performance);
  });
}
