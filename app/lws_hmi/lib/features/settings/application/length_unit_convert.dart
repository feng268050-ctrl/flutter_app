import 'package:lws_hmi/features/settings/application/common_settings_store.dart';

/// Length display helpers for Common Settings unit (Metric = mm, Imperial = in).
///
/// Conversion factor matches lws-ui `InchMillimeterUtils` (`MM_PER_INCH = 25`).
abstract final class LengthUnitConvert {
  static const double mmPerInch = 25;

  /// lws-ui `WireConsumptionDisplayUtil` foot factor: 12 in/ft × 25 mm/in.
  static const double mmPerFoot = mmPerInch * 12;

  static bool isMetric(String? unitWire) =>
      unitWire == null || unitWire == CommonSettingsStore.unitMetric;

  static String suffix(String? unitWire) => isMetric(unitWire) ? 'mm' : 'in';

  /// Format a stored millimetre value for the active unit.
  static String formatMm(double valueMm, {required String? unitWire}) {
    if (isMetric(unitWire)) {
      return _trimZeros(valueMm);
    }
    return _trimZeros(_mmToIn(valueMm));
  }

  /// Cumulative wire consumption for Home / Monitor Work Info.
  ///
  /// Matches lws-ui `WireConsumptionDisplayUtil`, with metric detail under 1 m:
  /// - Metric: `< 1000 mm` → integer `mm`; `≥ 1000 mm` → `mm ~/ 1000` + `m`
  ///   (e.g. 1298 mm → `1` + `m`, 12980 mm → `12` + `m`).
  /// - Imperial: whole feet (`round(mm / 300)`).
  static ({String number, String unit}) formatWireConsumption(
    int lengthMm, {
    String? unitWire,
  }) {
    final safe = lengthMm < 0 ? 0 : lengthMm;
    if (!isMetric(unitWire)) {
      return (number: (safe / mmPerFoot).round().toString(), unit: 'ft');
    }
    if (safe < 1000) {
      return (number: safe.toString(), unit: 'mm');
    }
    return (number: (safe ~/ 1000).toString(), unit: 'm');
  }

  static double _mmToIn(double mm) {
    if (!mm.isFinite) {
      return 0;
    }
    final raw = mm / mmPerInch;
    return (raw * 1000).roundToDouble() / 1000.0;
  }

  static String _trimZeros(double value) {
    if (!value.isFinite) {
      return '0';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
