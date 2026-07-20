import 'package:lws_hmi/device/display_value.dart';

enum TempTrend { none, up, down }

/// Tracks last Celsius sample and rise/fall for Home / Settings temperature rows.
class TempSeries {
  double? _last;
  bool _overTemp = false;

  TempTrend trend = TempTrend.none;
  String display = kUnavailableDisplay;

  void setCelsius(double? celsius, {bool? overTemp}) {
    if (overTemp != null) {
      _overTemp = overTemp;
    }
    if (celsius == null) {
      trend = TempTrend.none;
      _last = null;
      display = _overTemp ? 'OVER TEMP' : kUnavailableDisplay;
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
    final text = '${celsius.toStringAsFixed(1)} °C';
    display = _overTemp ? '$text · OVER TEMP' : text;
  }

  void setOverTemp(bool overTemp) {
    _overTemp = overTemp;
    if (_last == null) {
      display = overTemp ? 'OVER TEMP' : kUnavailableDisplay;
      return;
    }
    final text = '${_last!.toStringAsFixed(1)} °C';
    display = overTemp ? '$text · OVER TEMP' : text;
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
