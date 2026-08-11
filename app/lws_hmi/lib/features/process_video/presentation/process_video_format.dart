import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Display helpers for Monitor process-video list/detail (lws-ui column labels).
abstract final class ProcessVideoFormat {
  static String workMode(ProcessType type, AppLocalizations l10n) =>
      ProcessModeLabels.wheelLabel(type, l10n);

  static String material(ProcessVideoRecord record, AppLocalizations l10n) {
    final snap = record.snapshot;
    final material = record.materialType ?? snap?.materialType;
    if (material != null) {
      return material.localizedLabel(l10n);
    }
    final name = snap?.materialName?.trim();
    if (name != null && name.isNotEmpty) {
      return MaterialTypeAliases.localizeStored(name, l10n);
    }
    return '—';
  }

  static String recordingTime(ProcessVideoRecord record) {
    final t = record.createTime;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  static String duration(int durationMs) {
    final totalSec = (durationMs / 1000).floor().clamp(0, 99 * 3600);
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String parameterLabel(
    String key, {
    required AppLocalizations l10n,
    String? activeUnitWire,
  }) {
    final label = localizedProcessParameterLabel(l10n, key);
    final unit = parameterUnit(key, activeUnitWire: activeUnitWire);
    if (ProcessParameterCatalog.byKey[key] == null) {
      return key;
    }
    return unit.isEmpty ? label : '$label ($unit)';
  }

  /// Plain catalog label without unit (lws-ui detail rows use a separate unit).
  static String parameterLabelPlain(String key, AppLocalizations l10n) {
    return localizedProcessParameterLabel(l10n, key);
  }

  /// Display unit for [key], or empty when the parameter is unitless.
  static String parameterUnit(
    String key, {
    String? activeUnitWire,
  }) {
    final spec = ProcessParameterCatalog.byKey[key];
    if (spec == null) {
      return '';
    }
    final unit = spec.unit;
    if (unit.isEmpty) {
      return '';
    }
    final isMetric = LengthUnitConvert.isMetric(activeUnitWire);
    return isMetric ? unit : _convertUnitForImperial(unit);
  }

  static String parameterValue(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  static String _convertUnitForImperial(String unit) {
    switch (unit) {
      case 'mm':
        return 'in';
      case 'mm/s':
        return 'in/s';
      default:
        return unit;
    }
  }
}
