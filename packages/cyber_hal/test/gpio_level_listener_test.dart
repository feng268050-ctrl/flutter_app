import 'dart:io';

import 'package:cyber_hal/gpio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cyber_hal_gpio_level_');
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  test('GpioHal level listener fires on each successful set', () async {
    final red = File('${tmp.path}/led_red/value');
    red.parent.createSync(recursive: true);
    red.writeAsStringSync('0');

    final config = GpioConfig.fromJson({
      'version': 1,
      'defaults': {'active_low': false, 'blink_on_ms': 1000, 'blink_off_ms': 1000},
      'lines': [
        {
          'id': 'led_red',
          'path': red.path,
          'roles': ['indicator'],
        },
      ],
      'capabilities': {
        'set_level': true,
        'blink': true,
        'read_level': true,
      },
    });

    final hal = GpioHal.fromConfig(config);
    final events = <(String, bool)>[];
    hal.addLevelListener((id, high) => events.add((id, high)));

    final line = hal.openLine('led_red');
    expect(await line.get(), isFalse);

    await line.set(true);
    await line.set(false);
    await line.set(true);

    expect(events, [
      ('led_red', true),
      ('led_red', false),
      ('led_red', true),
    ]);
    expect(await line.get(), isTrue);

    await hal.dispose();
  });
}
