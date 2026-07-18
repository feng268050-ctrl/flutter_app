import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boardsRoot = Directory.current.path.endsWith('cyber_hal')
      ? 'boards'
      : 'packages/cyber_hal/boards';

  test('sim board profile advertises limited capabilities', () {
    final json = File('$boardsRoot/sim.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    expect(profile.info.boardId, 'sim');
    expect(profile.capabilities.has(Capability.backlight), isTrue);
    expect(profile.capabilities.has(Capability.volume), isTrue);
    expect(profile.capabilities.has(Capability.sysInfo), isTrue);
    expect(profile.capabilities.has(Capability.datetime), isTrue);
    expect(profile.capabilities.has(Capability.keyboard), isTrue);
    expect(profile.capabilities.has(Capability.mouse), isTrue);
    expect(profile.capabilities.has(Capability.gpio), isFalse);
    expect(profile.capabilities.has(Capability.modbus), isFalse);
    expect(profile.capabilities.has(Capability.bluetooth), isFalse);
    expect(profile.gpioConfigAsset, isNull);
    expect(profile.modbusConfigAsset, isNull);
  });

  test('resolveHalBackend selects stub for sim / HAL_BACKEND', () {
    expect(resolveHalBackend(boardId: 'sim'), HalBackendKind.stub);
    expect(resolveHalBackend(env: 'stub'), HalBackendKind.stub);
    expect(resolveHalBackend(env: 'sim'), HalBackendKind.stub);
    expect(resolveHalBackend(boardId: 'ynh960'), HalBackendKind.linux);
  });

  test('stub backlight / volume / sys_info round-trip', () async {
    final backlight = StubBacklight(initialPercent: 40);
    await backlight.setBrightnessPercent(90);
    expect(await backlight.getBrightnessPercent(), 90);

    final volume = StubVolume(initialPercent: 10);
    await volume.setVolumePercent(70);
    await volume.setMuted(true);
    expect(await volume.getVolumePercent(), 70);
    expect(await volume.isMuted(), isTrue);

    final snap = await StubSysInfo().snapshot();
    expect(snap.serialNumber, 'SIM-0001');
    expect(snap.boardModel, 'sim');
  });
}
