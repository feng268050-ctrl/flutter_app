import 'package:cyber_hal/gpio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

void main() {
  test('setMode skips HAL when mode unchanged (preserves blink)', () async {
    final fake = _FakeGpioHal();
    final leds = GpioLedController(hal: fake);

    await leds.setMode(LedColor.red, IndicatorMode.blink);
    expect(fake.setModeCalls, [('red', LedMode.blink)]);

    await leds.setMode(LedColor.red, IndicatorMode.blink);
    expect(fake.setModeCalls.length, 1);

    await leds.setMode(LedColor.red, IndicatorMode.steadyOn);
    expect(fake.setModeCalls.last, ('red', LedMode.steady));
    expect(fake.setModeCalls.length, 2);

    leds.dispose();
  });

  test('first Off still applies when cache starts unset', () async {
    final fake = _FakeGpioHal();
    final leds = GpioLedController(hal: fake);

    expect(leds.modeOf(LedColor.green), IndicatorMode.off);
    await leds.setMode(LedColor.green, IndicatorMode.off);
    expect(fake.setModeCalls, [('green', LedMode.off)]);

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
        ('red', LedMode.off),
        ('yellow', LedMode.off),
        ('green', LedMode.off),
      ],
    );
    expect(leds.modeOf(LedColor.red), IndicatorMode.off);
    expect(leds.modeOf(LedColor.yellow), IndicatorMode.off);
    expect(leds.modeOf(LedColor.green), IndicatorMode.off);

    fake.setModeCalls.clear();
    await leds.resetAllOff();
    expect(fake.setModeCalls.length, 3);

    leds.dispose();
  });
}

class _FakeGpioHal implements GpioHal {
  final List<(String, LedMode)> setModeCalls = [];
  late final _FakeStatusLedBank _bank = _FakeStatusLedBank(this);

  @override
  GpioConfig get config => throw UnimplementedError();

  @override
  GpioLine openLine(String id) => throw UnimplementedError();

  @override
  StatusLedBank openStatusLed(String id) {
    expect(id, LedColor.bankId);
    return _bank;
  }

  @override
  GpioBuzzer openBuzzer(String id) => throw UnimplementedError();

  @override
  GpioButton openButton(String id) => throw UnimplementedError();

  @override
  RotaryEncoder openEncoder(String id) => throw UnimplementedError();

  @override
  StubLogicalGpioLine? debugStubLine(String id) => null;

  @override
  void addLevelListener(GpioLevelListener listener) {}

  @override
  void removeLevelListener(GpioLevelListener listener) {}

  @override
  Future<void> dispose() async {}
}

class _FakeStatusLedBank implements StatusLedBank {
  _FakeStatusLedBank(this.hal);

  final _FakeGpioHal hal;
  final Map<String, LedMode?> _modes = {};

  @override
  String get id => LedColor.bankId;

  @override
  List<String> get channelIds =>
      LedColor.values.map((c) => c.channelId).toList();

  @override
  Future<void> setMode(String channelId, LedMode mode, {bool force = false}) async {
    if (!force && _modes[channelId] == mode) {
      return;
    }
    hal.setModeCalls.add((channelId, mode));
    _modes[channelId] = mode;
  }

  @override
  LedMode modeOf(String channelId) => _modes[channelId] ?? LedMode.off;

  @override
  Future<bool> isOn(String channelId) async => false;

  @override
  Future<void> dispose() async {}
}
