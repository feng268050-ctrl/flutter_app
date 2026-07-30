import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/settings/application/temperature_unit_convert.dart';

enum TempTrend { none, up, down }

/// Tracks last Celsius sample and rise/fall for Home / Settings temperature rows.
class TempSeries {
  double? _last;
  bool _overTemp = false;

  TempTrend trend = TempTrend.none;

  /// Last sample in Celsius (`null` = unavailable).
  double? get lastCelsius => _last;

  bool get overTemp => _overTemp;

  /// Metric (°C) display for callers that do not pass a unit preference.
  String get display => displayFor(null);

  /// Formats the stored Celsius sample for [unitWire] (Common Settings).
  String displayFor(String? unitWire) {
    if (_last == null) {
      return _overTemp ? 'OVER TEMP' : kUnavailableDisplay;
    }
    final text = TemperatureUnitConvert.formatSensorCelsius(_last!, unitWire);
    return _overTemp ? '$text · OVER TEMP' : text;
  }

  void setCelsius(double? celsius, {bool? overTemp}) {
    if (overTemp != null) {
      _overTemp = overTemp;
    }
    if (celsius == null) {
      trend = TempTrend.none;
      _last = null;
      return;
    }
    if (_last != null) {
      if (celsius > _last!) {
        trend = TempTrend.up;
      } else if (celsius < _last!) {
        trend = TempTrend.down;
      } else {
        trend = TempTrend.none;
      }
    }
    _last = celsius;
  }

  void setOverTemp(bool overTemp) {
    _overTemp = overTemp;
  }
}

/// Decode Modbus temp register → °C (`null` = unavailable).
double? modbusTempCelsius(Object? value) {
  if (value is int) {
    if (value <= -999) {
      return null;
    }
    return value / 10.0;
  }
  if (value is num) {
    if (value <= -99.9) {
      return null;
    }
    return value.toDouble();
  }
  return null;
}
