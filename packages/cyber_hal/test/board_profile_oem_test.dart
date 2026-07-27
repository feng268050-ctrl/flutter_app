import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oemBoard = Directory.current.path.endsWith('cyber_hal')
      ? '../../oem/boards/ynh960/board_profile.json'
      : 'oem/boards/ynh960/board_profile.json';

  test('loadFile reads OEM ynh960 profile without product catalogs', () async {
    final profile = await BoardProfile.loadFile(oemBoard);
    expect(profile.info.boardId, 'ynh960');
    expect(profile.resolvedGpioAsset, isNull);
    expect(profile.resolvedModbusAsset, isNull);
    expect(profile.helper(BoardHelperKeys.wifiModem),
        '/usr/libexec/bluetooth/wifibt-bringup.sh');
  });

  test('withProductConfigs merges App gpio/modbus assets', () async {
    final oem = await BoardProfile.loadFile(oemBoard);
    final merged = oem.withProductConfigs(
      gpio: 'assets/hal/gpio.json',
      modbus: 'assets/hal/modbus.json',
    );
    expect(merged.info.boardId, 'ynh960');
    expect(merged.resolvedGpioAsset, 'assets/hal/gpio.json');
    expect(merged.resolvedModbusAsset, 'assets/hal/modbus.json');
    expect(merged.ifaceFor(NetRole.ethernetPrimary), 'eth0');
  });

  test('loadFile missing path throws HalIoException', () async {
    expect(
      () => BoardProfile.loadFile('/tmp/lws-hmi-missing-board-profile.json'),
      throwsA(isA<HalIoException>()),
    );
  });
}
