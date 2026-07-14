import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/gpio/gpio_led_config.dart';

void main() {
  test('RGB pins match original lws-ui GpioLedConfig (5/4/7)', () {
    expect(LedColor.red.ynhApiPin, 5);
    expect(LedColor.yellow.ynhApiPin, 4);
    expect(LedColor.green.ynhApiPin, 7);
    expect(LedColor.red.linuxGpio, 105);
    expect(LedColor.yellow.linuxGpio, 106);
    expect(LedColor.green.linuxGpio, 149);
  });
}
