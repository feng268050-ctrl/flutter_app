import 'dart:io';

import 'package:cyber_hal/gpio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

void main() {
  final halRoot = Directory.current.path.endsWith('lws_hmi')
      ? 'assets/hal'
      : 'app/lws_hmi/assets/hal';

  test('RGB channel ids match product gpio.ynh960.json (5/4/7 → 105/106/149)', () {
    final json = File('$halRoot/gpio.ynh960.json').readAsStringSync();
    final config = GpioConfig.fromJsonString(json);

    expect(LedColor.red.channelId, 'red');
    expect(LedColor.yellow.channelId, 'yellow');
    expect(LedColor.green.channelId, 'green');
    expect(LedColor.bankId, 'chassis_rgb');

    final bank = config.deviceById(LedColor.bankId)!.statusLed!;
    final red = bank.channelById(LedColor.red.channelId)!;
    final yellow = bank.channelById(LedColor.yellow.channelId)!;
    final green = bank.channelById(LedColor.green.channelId)!;

    expect(red.binding.label, 'GPIO_5');
    expect(yellow.binding.label, 'GPIO_4');
    expect(green.binding.label, 'GPIO_7');
    expect(red.binding.fallbackLinuxGpio, 105);
    expect(yellow.binding.fallbackLinuxGpio, 106);
    expect(green.binding.fallbackLinuxGpio, 149);
    expect(red.binding.chip, 'gpiochip3');
    expect(red.binding.offset, 9);
    expect(green.binding.chip, 'gpiochip4');
    expect(green.binding.offset, 21);

    expect(config.deviceById('panel_buzzer')?.buzzer?.line.label, 'BELL');
  });
}
