import 'package:lws_hmi/features/settings/application/common_settings_store.dart';

/// Length display helpers for Common Settings unit (Metric = mm, Imperial = in).
///
/// Conversion factor matches lws-ui `InchMillimeterUtils` (`MM_PER_INCH = 25`).
abstract final class LengthUnitConvert {
  static const double mmPerInch = 25;

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
