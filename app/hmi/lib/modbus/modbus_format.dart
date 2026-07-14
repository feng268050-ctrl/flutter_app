import 'package:lws_hmi/device/display_value.dart';

/// Format helpers matching lws-ui `ModbusFieldConvert` / Device Information UI.
String hexConcatRegisters(int high, int low) {
  return '${high.toRadixString(16)}${low.toRadixString(16)}';
}

String decimalRegister(int value) => value.toString();

/// Unsigned Modbus register word → signed int16 (lws-ui `ShortDataConvertUtils`).
int toSignedRegister16(int unsignedWord) {
  final v = unsignedWord & 0xFFFF;
  return v >= 0x8000 ? v - 0x10000 : v;
}

/// Sensor temperature display: raw×0.1 °C; `<= -999` → `-` (lws-ui `DeviceData.parseTemperature`).
String formatSensorTemperatureCelsius(int signedRaw) {
  if (signedRaw <= -999) {
    return kUnavailableDisplay;
  }
  return '${(signedRaw / 10.0).toStringAsFixed(1)} °C';
}
