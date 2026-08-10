import 'dart:io';

import 'package:cyber_hal/gpio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyber_hal/src/gpio/stub_logical_line.dart';

void main() {
  group('GpioConfig v1 / v2', () {
    test('v1 lines synthesize chassis_rgb status_led', () {
      final config = GpioConfig.fromJson({
        'version': 1,
        'backend': 'sysfs_innohi',
        'lines': [
          {
            'id': 'led_red',
            'label': 'GPIO_5',
            'path': '/tmp/fake/red',
            'roles': ['indicator'],
          },
          {
            'id': 'led_yellow',
            'label': 'GPIO_4',
            'path': '/tmp/fake/yellow',
            'roles': ['indicator'],
          },
        ],
      });

      expect(config.devices, hasLength(1));
      expect(config.devices.single.id, 'chassis_rgb');
      expect(config.devices.single.type, GpioDeviceType.statusLed);
      final channels = config.devices.single.statusLed!.channels;
      expect(channels.map((c) => c.id), ['red', 'yellow']);
      expect(config.lineById('led_red'), isNotNull);
    });

    test('v2 variable channels and alternate sysfs path', () {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'sysfs',
        'devices': [
          {
            'type': 'status_led',
            'id': 'panel',
            'channels': [
              {
                'id': 'fault',
                'scheme': 'sysfs',
                'path': '/sys/class/other_gpio/FAULT/value',
              },
              {
                'id': 'ok',
                'scheme': 'sysfs',
                'path': '/sys/class/other_gpio/OK/value',
              },
            ],
          },
        ],
        'capabilities': {
          'status_led': true,
          'buzzer': false,
          'button': false,
          'rotary_encoder': false,
        },
      });

      expect(config.devices.single.statusLed!.channels, hasLength(2));
      expect(
        config.devices.single.statusLed!.channels.first.binding.path,
        '/sys/class/other_gpio/FAULT/value',
      );
      expect(config.capabilities.allows(GpioDeviceType.buzzer), isFalse);
    });

    test('minimal one-channel config has no baked pin constants', () {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'stub',
        'devices': [
          {
            'type': 'status_led',
            'id': 'only',
            'channels': [
              {'id': 'a', 'scheme': 'stub'},
            ],
          },
        ],
        'capabilities': {'buzzer': false},
      });

      expect(config.deviceById('panel_buzzer'), isNull);
      expect(config.devices.single.statusLed!.channels.single.id, 'a');
      // No implied GPIO_5 / linux 105 from HAL — only what config declared.
      expect(
        config.devices.single.statusLed!.channels.single.binding.label,
        isNull,
      );
      expect(
        config.devices.single.statusLed!.channels.single.binding.fallbackLinuxGpio,
        isNull,
      );
    });

    test('v2 dual addressing records gpiod without selecting it', () {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'sysfs_innohi',
        'devices': [
          {
            'type': 'buzzer',
            'id': 'panel_buzzer',
            'line': {
              'scheme': 'sysfs_innohi',
              'label': 'BELL',
              'path': '/sys/class/gpio_innohi/BELL/value',
              'gpiod': {'chip': 'gpiochip3', 'offset': 27},
              'linux_gpio': 123,
            },
          },
        ],
      });

      final line = config.devices.single.buzzer!.line;
      expect(line.scheme, GpioBindingScheme.sysfs);
      expect(line.label, 'BELL');
      expect(line.chip, 'gpiochip3');
      expect(line.offset, 27);
      expect(line.fallbackLinuxGpio, 123);
    });
  });

  group('devices (stub)', () {
    test('StatusLedBank independent channels + blink idempotent', () async {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'stub',
        'defaults': {'blink_on_ms': 40, 'blink_off_ms': 40},
        'devices': [
          {
            'type': 'status_led',
            'id': 'chassis_rgb',
            'channels': [
              {'id': 'red', 'scheme': 'stub'},
              {'id': 'green', 'scheme': 'stub'},
            ],
          },
        ],
      });
      final hal = GpioHal.fromConfig(config, forceStub: true);
      final bank = hal.openStatusLed('chassis_rgb');

      await bank.setMode('red', LedMode.steady);
      await bank.setMode('green', LedMode.blink);
      expect(await bank.isOn('red'), isTrue);
      expect(await bank.isOn('green'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(await bank.isOn('green'), isFalse);
      expect(await bank.isOn('red'), isTrue);

      await bank.setMode('green', LedMode.blink);
      expect(await bank.isOn('green'), isFalse);

      await hal.dispose();
    });

    test('Buzzer beep ends off', () async {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'stub',
        'devices': [
          {
            'type': 'buzzer',
            'id': 'panel_buzzer',
            'line': {'scheme': 'stub'},
          },
        ],
      });
      final hal = GpioHal.fromConfig(config, forceStub: true);
      final buzzer = hal.openBuzzer('panel_buzzer');
      final stub = hal.debugStubLine('panel_buzzer')!;
      await buzzer.beep(duration: const Duration(milliseconds: 30));
      expect(await stub.getLogical(), isFalse);
      await hal.dispose();
    });

    test('Button short and long press', () async {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'stub',
        'defaults': {
          'button_debounce_ms': 5,
          'button_long_press_ms': 40,
        },
        'devices': [
          {
            'type': 'button',
            'id': 'front_key',
            'line': {'scheme': 'stub'},
          },
        ],
        'capabilities': {'button': true},
      });
      final hal = GpioHal.fromConfig(config, forceStub: true);
      final button = hal.openButton('front_key');
      final events = <GpioButtonEventKind>[];
      final sub = button.events.listen((e) => events.add(e.kind));

      final stub = hal.debugStubLine('front_key')!;
      stub.injectLogical(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      stub.injectLogical(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, [
        GpioButtonEventKind.pressed,
        GpioButtonEventKind.released,
      ]);

      events.clear();
      stub.injectLogical(true);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(events, contains(GpioButtonEventKind.longPressed));
      stub.injectLogical(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sub.cancel();
      await hal.dispose();
    });

    test('RotaryEncoder CW step after Gray sequence', () async {
      final config = GpioConfig.fromJson({
        'version': 2,
        'backend': 'stub',
        'defaults': {'encoder_debounce_ms': 0},
        'devices': [
          {
            'type': 'rotary_encoder',
            'id': 'knob',
            'a': {'scheme': 'stub'},
            'b': {'scheme': 'stub'},
          },
        ],
        'capabilities': {'rotary_encoder': true},
      });
      final hal = GpioHal.fromConfig(config, forceStub: true);
      final enc = hal.openEncoder('knob');
      final steps = <EncoderStepDirection>[];
      final sub = enc.steps.listen((s) => steps.add(s.direction));

      final a = hal.debugStubLine('knob_a')!;
      final b = hal.debugStubLine('knob_b')!;
      await a.setLogical(false);
      await b.setLogical(false);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      a.injectLogical(true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.injectLogical(true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      a.injectLogical(false);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      b.injectLogical(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(steps, isNotEmpty);
      expect(steps.first, EncoderStepDirection.clockwise);

      await sub.cancel();
      await hal.dispose();
    });
  });

  test('sysfs StatusLed via temp value files', () async {
    final tmp = Directory.systemTemp.createTempSync('cyber_hal_gpio_v2_');
    addTearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
    final red = File('${tmp.path}/red/value')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('0');
    final green = File('${tmp.path}/green/value')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('0');

    final config = GpioConfig.fromJson({
      'version': 2,
      'backend': 'sysfs',
      'defaults': {'blink_on_ms': 1000, 'blink_off_ms': 1000},
      'devices': [
        {
          'type': 'status_led',
          'id': 'chassis_rgb',
          'channels': [
            {'id': 'red', 'scheme': 'sysfs', 'path': red.path},
            {'id': 'green', 'scheme': 'sysfs', 'path': green.path},
          ],
        },
      ],
    });
    final hal = GpioHal.fromConfig(config);
    final bank = hal.openStatusLed('chassis_rgb');
    await bank.setMode('red', LedMode.steady);
    expect(red.readAsStringSync().trim(), '1');
    await bank.setMode('green', LedMode.off, force: true);
    expect(green.readAsStringSync().trim(), '0');
    await hal.dispose();
  });
}
