import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
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
        '/oem/boards/ynh960/helpers/wifibt-bringup.sh');
  });

  test('ynh960 OEM sets secrets_backend optee', () async {
    final profile = await BoardProfile.loadFile(oemBoard);
    expect(profile.secretsBackend, 'optee');
  });

  test('withProductConfigs merges App gpio/modbus assets', () async {
    final oem = await BoardProfile.loadFile(oemBoard);
    final merged = oem.withProductConfigs(
      gpio: 'assets/hal/gpio.ynh960.json',
      modbus: 'assets/hal/modbus.json',
    );
    expect(merged.info.boardId, 'ynh960');
    expect(merged.resolvedGpioAsset, 'assets/hal/gpio.ynh960.json');
    expect(merged.resolvedModbusAsset, 'assets/hal/modbus.json');
    expect(merged.ifaceFor(NetRole.ethernetPrimary), 'eth0');
  });

  test('sim OEM sets modbus_rtu_device for USB-serial', () async {
    final simBoard = Directory.current.path.endsWith('cyber_hal')
        ? '../../oem/boards/sim/board_profile.json'
        : 'oem/boards/sim/board_profile.json';
    final profile = await BoardProfile.loadFile(simBoard);
    expect(profile.helper(BoardHelperKeys.modbusRtuDevice), '/dev/ttyUSB0');
  });

  test('ModbusConfig.withTransportDevice overrides path', () {
    const t = ModbusTransport(
      type: 'rtu',
      device: '/dev/ttyS5',
      baud: 115200,
    );
    final cfg = ModbusConfig(
      version: 1,
      transport: t,
      attributes: const [],
    );
    final next = cfg.withTransportDevice('/dev/ttyUSB0');
    expect(next.transport.device, '/dev/ttyUSB0');
    expect(next.transport.baud, 115200);
    expect(identical(cfg.withTransportDevice('/dev/ttyS5'), cfg), isTrue);
  });

  test('device_by_board resolves ynh960 / ek3562 / sim; unknown falls back', () {
    final modbusPath = Directory.current.path.endsWith('cyber_hal')
        ? '../../app/lws_hmi/assets/hal/modbus.json'
        : 'app/lws_hmi/assets/hal/modbus.json';
    final cfg = ModbusConfig.fromJsonString(File(modbusPath).readAsStringSync());
    expect(cfg.transport.deviceByBoard.keys.toSet(),
        {'ynh960', 'ek3562', 'sim'});
    expect(cfg.deviceForBoard('ynh960'), '/dev/ttyS5');
    expect(cfg.deviceForBoard('ek3562'), '/dev/ttyS4');
    expect(cfg.deviceForBoard('sim'), '/dev/ttyUSB0');
    expect(cfg.deviceForBoard('ynh961'), '/dev/ttyS5');
    expect(cfg.withDeviceForBoard('ek3562').transport.device, '/dev/ttyS4');
  });

  test('loadFile missing path throws HalIoException', () async {
    expect(
      () => BoardProfile.loadFile('/tmp/lws-hmi-missing-board-profile.json'),
      throwsA(isA<HalIoException>()),
    );
  });
}
