import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Title-with-unit + description copy for engineer numeric dialogs (lws-ui).
abstract final class EngineerParameterInputCopy {
  static String titleWithUnit(AppLocalizations l10n, String title, String unit) {
    return l10n.inputDialogTitleWithUnit(title, unit);
  }

  /// Description under the dialog title (centered). Null when lws-ui omits it.
  static String? descriptionFor({
    required String key,
    required ProcessType processType,
    required AppLocalizations l10n,
    required ProcessParameterSpec spec,
  }) {
    final min = _formatBound(spec.min);
    final max = _formatBound(_effectiveMax(key, processType, spec.max));
    final unit = spec.unit;

    switch (key) {
      case 'process.blowing_delay':
        return l10n.paramGasPreFlowDesc;
      case 'process.gas_off_delay':
        return l10n.paramGasPostFlowDesc;
      case 'process.laser_power':
        return l10n.paramLaserPowerDesc;
      case 'process.power_ramp_up_duration':
        return l10n.paramRampUpTimeDesc;
      case 'process.power_ramp_down_duration':
        return l10n.paramRampDownTimeDesc;
      case 'process.swing_frequency':
        // lws-ui always advertises the recommended 20–220 Hz band.
        return l10n.paramScanFrequencyDesc('20', '220', 'Hz');
      case 'process.swing_width':
        return l10n.paramScanWidthDesc(min, max, unit);
      case 'process.wire_feeding_speed':
        return l10n.paramWireFeedSpeedDesc(min, max, unit);
      case 'process.light_off_delay':
        return l10n.paramLaserOffDelayDesc;
      case 'process.back_draw_length':
        return l10n.paramRetractLengthDesc(min, max, unit);
      case 'process.back_draw_speed':
        return l10n.paramRetractSpeedDesc(min, max, unit);
      case 'process.wire_filling_length':
        return l10n.paramRefeedLengthDesc(min, max, unit);
      case 'process.wire_filling_delay':
        return l10n.paramRefeedDelayDesc;
      case 'process.spot_welding_interval':
        return l10n.paramSpotWeldIntervalDesc;
      case 'process.spot_welding_duration':
        return l10n.paramSpotWeldDurationDesc;
      default:
        return l10n.paramGenericRangeDesc(min, max, unit);
    }
  }

  static bool usesDecimalStep(String key) {
    switch (key) {
      case 'process.swing_width':
      case 'process.back_draw_length':
      case 'process.wire_filling_length':
        return true;
      default:
        return false;
    }
  }

  static double effectiveMax(
    String key,
    ProcessType processType,
    double catalogMax,
  ) =>
      _effectiveMax(key, processType, catalogMax);

  static double _effectiveMax(
    String key,
    ProcessType processType,
    double catalogMax,
  ) {
    if (key == 'process.swing_width' &&
        processType == ProcessType.wideCleaning) {
      return 30;
    }
    return catalogMax;
  }

  static String _formatBound(num value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }
}
