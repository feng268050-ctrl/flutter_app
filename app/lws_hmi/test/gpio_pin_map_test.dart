import 'dart:io';

import 'package:cyber_hal/gpio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

void main() {
  final halRoot = Directory.current.path.endsWith('lws_hmi')
      ? 'assets/hal'
      : 'app/lws_hmi/assets/hal';

  test('RGB line ids match product gpio.json (5/4/7 → 105/106/149)', () {
    final json = File('$halRoot/gpio.json').readAsStringSync();
    final config = GpioConfig.fromJsonString(json);

    expect(LedColor.red.lineId, 'led_red');
    expect(LedColor.yellow.lineId, 'led_yellow');
    expect(LedColor.green.lineId, 'led_green');

    expect(config.lineById(LedColor.red.lineId)!.label, 'GPIO_5');
    expect(config.lineById(LedColor.yellow.lineId)!.label, 'GPIO_4');
    expect(config.lineById(LedColor.green.lineId)!.label, 'GPIO_7');
    expect(config.lineById(LedColor.red.lineId)!.fallbackLinuxGpio, 105);
    expect(config.lineById(LedColor.yellow.lineId)!.fallbackLinuxGpio, 106);
    expect(config.lineById(LedColor.green.lineId)!.fallbackLinuxGpio, 149);
  });
}
