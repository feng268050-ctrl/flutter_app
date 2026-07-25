import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/modbus/modbus_crc.dart';
import 'package:lws_hmi/modbus/modbus_format.dart';

void main() {
  test('modbus CRC matches known RTU frame', () {
    // Read input registers: slave 1, start 0x0002, count 1
    final pdu = <int>[0x01, 0x04, 0x00, 0x02, 0x00, 0x01];
    final frame = appendModbusCrc(pdu);
    expect(verifyModbusCrc(frame), isTrue);
    expect(frame.length, 8);
  });

  test('hex concat matches lws-ui style', () {
    expect(hexConcatRegisters(0x2025, 0x730), '2025730');
    expect(decimalRegister(1014), '1014');
  });

  test('sensor temperature formatting matches lws-ui scale', () {
    expect(toSignedRegister16(0xFFFE), -2);
    expect(formatSensorTemperatureCelsius(253), '25.3 °C');
    expect(formatSensorTemperatureCelsius(-999), '-');
    expect(formatSensorTemperatureCelsius(-1000), '-');
  });
}
