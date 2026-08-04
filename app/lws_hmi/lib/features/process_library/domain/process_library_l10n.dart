import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// UI-facing labels for process library enums / parameter catalog keys.
extension ProcessTypeL10n on ProcessType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        ProcessType.continuousWelding => l10n.processTypeContinuousWelding,
        ProcessType.spotWelding => l10n.processTypeSpotWelding,
        ProcessType.weldCleaning => l10n.processTypeWeldCleaning,
        ProcessType.wideCleaning => l10n.processTypeWideCleaning,
        ProcessType.handCutting => l10n.processTypeHandCutting,
        ProcessType.cncCutting => l10n.processTypeCncCutting,
      };
}

extension MaterialTypeL10n on MaterialType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        MaterialType.stainlessSteel => l10n.materialStainlessSteel,
        MaterialType.carbonSteel => l10n.materialCarbonSteel,
        MaterialType.galvanizedSheet => l10n.materialGalvanizedSheet,
        MaterialType.aluminumAlloy => l10n.materialAluminumAlloy,
        MaterialType.brass => l10n.materialBrass,
        MaterialType.custom => l10n.materialCustom,
      };
}

/// Resolve stored library strings (often Chinese Excel) to [MaterialType].
abstract final class MaterialTypeAliases {
  static const _exact = <String, MaterialType>{
    '不锈钢': MaterialType.stainlessSteel,
    '不鏽鋼': MaterialType.stainlessSteel,
    '碳钢': MaterialType.carbonSteel,
    '碳鋼': MaterialType.carbonSteel,
    '镀锌板': MaterialType.galvanizedSheet,
    '鍍鋅板': MaterialType.galvanizedSheet,
    '铝合金': MaterialType.aluminumAlloy,
    '鋁合金': MaterialType.aluminumAlloy,
    '黄铜': MaterialType.brass,
    '黃銅': MaterialType.brass,
    '自定义': MaterialType.custom,
    '自定義': MaterialType.custom,
    'Stainless steel': MaterialType.stainlessSteel,
    'Stainless Steel': MaterialType.stainlessSteel,
    'Carbon steel': MaterialType.carbonSteel,
    'Carbon Steel': MaterialType.carbonSteel,
    'Galvanized sheet': MaterialType.galvanizedSheet,
    'Galvanized Sheet': MaterialType.galvanizedSheet,
    'Aluminum alloy': MaterialType.aluminumAlloy,
    'Aluminum Alloy': MaterialType.aluminumAlloy,
    'Brass': MaterialType.brass,
    'Custom': MaterialType.custom,
  };

  static MaterialType? resolve(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final exact = _exact[trimmed];
    if (exact != null) {
      return exact;
    }
    final lower = trimmed.toLowerCase();
    for (final material in MaterialType.values) {
      if (lower == material.label.toLowerCase() ||
          lower == material.englishName.toLowerCase()) {
        return material;
      }
    }
    return null;
  }

  /// Localize a stored material / process-name string for the active locale.
  static String localizeStored(String raw, AppLocalizations l10n) {
    final exact = resolve(raw);
    if (exact != null) {
      return exact.localizedLabel(l10n);
    }
    // "不锈钢-2mm" / "Stainless Steel-2mm" → localized prefix + remainder.
    final aliases = _exact.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final alias in aliases) {
      if (raw.startsWith(alias)) {
        final material = _exact[alias]!;
        return '${material.localizedLabel(l10n)}${raw.substring(alias.length)}';
      }
    }
    return raw;
  }
}

extension ProcessPresetDisplayL10n on ProcessPreset {
  /// Material pill label — prefer enum l10n over raw Excel `material_name`.
  String displayMaterialLabel(AppLocalizations l10n) {
    if (materialType != null) {
      return materialType!.localizedLabel(l10n);
    }
    final raw = materialName;
    if (raw == null || raw.isEmpty) {
      return '—';
    }
    return MaterialTypeAliases.localizeStored(raw, l10n);
  }

  /// Process title — map known material aliases so English UI stays English.
  String displayProcessName(AppLocalizations l10n) =>
      MaterialTypeAliases.localizeStored(name, l10n);
}

/// Localized catalog / engineer-facing parameter row titles.
String localizedProcessParameterLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'process.laser_power' => l10n.paramLaserPower,
    'process.laser_duty_cycle' => l10n.paramLaserDutyCycle,
    'process.laser_frequency' => l10n.paramLaserFrequency,
    'process.piercing_power' => l10n.paramPiercingPower,
    'process.piercing_frequency' => l10n.paramPiercingFrequency,
    'process.piercing_duty_cycle' => l10n.paramPiercingDutyCycle,
    'process.swing_frequency' => l10n.paramSwingFrequencyCatalog,
    'process.swing_width' => l10n.swingWidthLabel,
    'process.wire_feeding_speed' => l10n.paramWireFeedingSpeedCatalog,
    'process.back_draw_length' => l10n.paramBackDrawLengthCatalog,
    'process.back_draw_speed' => l10n.paramBackDrawSpeedCatalog,
    'process.wire_filling_length' => l10n.paramWireFillingLengthCatalog,
    'process.wire_filling_delay' => l10n.paramWireFillingDelayCatalog,
    'process.wire_feeding_delay' => l10n.paramWireFeedingDelay,
    'process.blowing_delay' => l10n.paramBlowingDelayCatalog,
    'process.gas_off_delay' => l10n.paramGasOffDelayCatalog,
    'process.light_off_delay' => l10n.paramLightOffDelayCatalog,
    'process.power_ramp_up_duration' => l10n.paramPowerRampUp,
    'process.power_ramp_down_duration' => l10n.paramPowerRampDown,
    'process.spot_welding_duration' => l10n.paramSpotWeldingDurationCatalog,
    'process.spot_welding_interval' => l10n.paramSpotWeldingIntervalCatalog,
    'process.piercing_duration' => l10n.paramPiercingDuration,
    _ => ProcessParameterCatalog.byKey[key]?.label ?? key,
  };
}
