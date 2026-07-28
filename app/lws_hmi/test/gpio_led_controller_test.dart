import 'package:cyber_hal/gpio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

void main() {
  test('setMode skips HAL when mode unchanged (preserves blink)', () async {
    final fake = _FakeGpioHal();
    final leds = GpioLedController(hal: fake);

    await leds.setMode(LedColor.red, IndicatorMode.blink);
    expect(fake.setModeCalls, [('led_red', GpioLineMode.blink)]);

    await leds.setMode(LedColor.red, IndicatorMode.blink);
    expect(fake.setModeCalls.length, 1);

    await leds.setMode(LedColor.red, IndicatorMode.steadyOn);
    expect(fake.setModeCalls.last, ('led_red', GpioLineMode.steady));
    expect(fake.setModeCalls.length, 2);

    leds.dispose();
  });

  test('first Off still applies when cache starts unset', () async {
    final fake = _FakeGpioHal();
    final leds = GpioLedController(hal: fake);

    expect(leds.modeOf(LedColor.green), IndicatorMode.off);
    await leds.setMode(LedColor.green, IndicatorMode.off);
    expect(fake.setModeCalls, [('led_green', GpioLineMode.off)]);

    await leds.setMode(LedColor.green, IndicatorMode.off);
    expect(fake.setModeCalls.length, 1);

    leds.dispose();
  });

  test('resetAllOff force-writes Off for every color', () async {
    final fake = _FakeGpioHal();
    final leds = GpioLedController(hal: fake);

    await leds.setMode(LedColor.green, IndicatorMode.steadyOn);
    await leds.setMode(LedColor.red, IndicatorMode.blink);
    fake.setModeCalls.clear();

    await leds.resetAllOff();
    expect(
      fake.setModeCalls,
      [
        ('led_red', GpioLineMode.off),
        ('led_yellow', GpioLineMode.off),
        ('led_green', GpioLineMode.off),
      ],
    );
    expect(leds.modeOf(LedColor.red), IndicatorMode.off);
    expect(leds.modeOf(LedColor.yellow), IndicatorMode.off);
    expect(leds.modeOf(LedColor.green), IndicatorMode.off);

    // Second reset still force-writes (boot / re-start safety).
    fake.setModeCalls.clear();
    await leds.resetAllOff();
    expect(fake.setModeCalls.length, 3);

    leds.dispose();
  });
}

class _FakeGpioHal implements GpioHal {
  final List<(String, GpioLineMode)> setModeCalls = [];
  final Map<String, _FakeLine> _lines = {};

  @override
  GpioConfig get config => throw UnimplementedError();

  @override
  GpioLine openLine(String id) =>
      _lines.putIfAbsent(id, () => _FakeLine(this, id));

  @override
  void addLevelListener(GpioLevelListener listener) {}

  @override
  void removeLevelListener(GpioLevelListener listener) {}

  @override
  Future<void> dispose() async {}
}

class _FakeLine implements GpioLine {
  _FakeLine(this.hal, this.id);

  final _FakeGpioHal hal;

  @override
  final String id;

  GpioLineMode? _mode;

  @override
  Future<void> set(bool high) async {}

  @override
  Future<bool> get() async => false;

  @override
  Future<void> setMode(GpioLineMode mode, {bool force = false}) async {
    if (!force && _mode == mode) {
      return;
    }
    hal.setModeCalls.add((id, mode));
    _mode = mode;
  }

  @override
  GpioLineMode get mode => _mode ?? GpioLineMode.off;
}
