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
