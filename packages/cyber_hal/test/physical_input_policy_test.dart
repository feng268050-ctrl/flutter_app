import 'package:cyber_hal/input/physical_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parsePhysicalInputEnabled defaults and values', () {
    expect(parsePhysicalInputEnabled(null), isTrue);
    expect(parsePhysicalInputEnabled('0'), isFalse);
    expect(parsePhysicalInputEnabled('1'), isTrue);
    expect(parsePhysicalInputEnabled('false'), isFalse);
    expect(parsePhysicalInputEnabled('yes'), isTrue);
  });

  test('physicalInputFlagsFromMap reads keys', () {
    final flags = physicalInputFlagsFromMap({
      kPhysicalKeyboardEnabledKey: '0',
      kPhysicalMouseEnabledKey: '1',
    });
    expect(flags.keyboardEnabled, isFalse);
    expect(flags.mouseEnabled, isTrue);
  });

  test('encodePhysicalInputEnabled', () {
    expect(encodePhysicalInputEnabled(true), '1');
    expect(encodePhysicalInputEnabled(false), '0');
  });
}
