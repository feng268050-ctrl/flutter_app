/// Shared display placeholder when a Modbus field cannot be read.
const String kModbusUnavailableDisplay = '-';

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

/// Sensor temperature display: raw×0.1 °C; `<= -999` → `-`.
String formatSensorTemperatureCelsius(int signedRaw) {
  if (signedRaw <= -999) {
    return kModbusUnavailableDisplay;
  }
  return '${(signedRaw / 10.0).toStringAsFixed(1)} °C';
}

/// Display helper for decoded temps: raw `int` (×0.1) or already-scaled `num`.
String formatTemperatureDisplay(Object? decoded) {
  if (decoded is int) {
    return formatSensorTemperatureCelsius(decoded);
  }
  if (decoded is num) {
    // Scaled with 0.1: sentinel raw -999 → -99.9
    if (decoded <= -99.9) {
      return kModbusUnavailableDisplay;
    }
    return '${decoded.toStringAsFixed(1)} °C';
  }
  return kModbusUnavailableDisplay;
}
