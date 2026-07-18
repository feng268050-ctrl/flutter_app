import 'package:cyber_hal/modbus.dart' as hal;
import 'package:lws_hmi/device/display_value.dart';

export 'package:cyber_hal/modbus.dart'
    show decimalRegister, hexConcatRegisters, toSignedRegister16;

/// Sensor temperature display: raw×0.1 °C; `<= -999` → [kUnavailableDisplay].
String formatSensorTemperatureCelsius(int signedRaw) {
  final s = hal.formatSensorTemperatureCelsius(signedRaw);
  return s == hal.kModbusUnavailableDisplay ? kUnavailableDisplay : s;
}
