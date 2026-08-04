import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_l10n.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Engineer-mode row title + optional colored `(Tn)` / `(P)` suffix (lws-ui).
///
/// Catalog [ProcessParameterSpec.label] stays generic for process library;
/// this layer owns the welding English names and T markers.
final class EngineerParameterPresentation {
  const EngineerParameterPresentation({
    required this.label,
    this.suffix,
    this.suffixColor,
  });

  final String label;
  final String? suffix;
  final Color? suffixColor;

  static const _t2Orange = Color(0xFFFFC266);
  static const _t3Weld = Color(0xFFFD7632);
  static const _t4Blue = Color(0xFF324BF3);
  static const _t1Blue = Color(0xFF324BF3);

  static EngineerParameterPresentation forKey(
    String key,
    ProcessType processType,
    AppLocalizations l10n,
  ) {
    final welding = processType == ProcessType.continuousWelding ||
        processType == ProcessType.spotWelding;
    final continuous = processType == ProcessType.continuousWelding;

    switch (key) {
      case 'process.spot_welding_interval':
        return EngineerParameterPresentation(
          label: l10n.paramSpotWeldInterval,
          suffix: '(T1)',
          suffixColor: _t1Blue,
        );
      case 'process.spot_welding_duration':
        return EngineerParameterPresentation(
          label: l10n.paramSpotWeldDuration,
          suffix: '(T2)',
          suffixColor: _t3Weld,
        );
      case 'process.blowing_delay':
        return EngineerParameterPresentation(label: l10n.paramGasPreFlow);
      case 'process.power_ramp_up_duration':
        return EngineerParameterPresentation(
          label: l10n.paramRampUpTime,
          suffix: continuous ? '(T2)' : null,
          suffixColor: continuous ? _t2Orange : null,
        );
      case 'process.laser_power':
        return EngineerParameterPresentation(
          label: l10n.paramLaserPower,
          suffix: welding ? '(P)' : null,
        );
      case 'process.power_ramp_down_duration':
        return EngineerParameterPresentation(
          label: l10n.paramRampDownTime,
          suffix: continuous ? '(T3)' : null,
          suffixColor: continuous ? _t3Weld : null,
        );
      case 'process.gas_off_delay':
        return EngineerParameterPresentation(
          label: l10n.paramGasPostFlow,
          suffix: continuous ? '(T4)' : null,
          suffixColor: continuous ? _t4Blue : null,
        );
      case 'process.swing_frequency':
        return EngineerParameterPresentation(label: l10n.paramScanFrequency);
      case 'process.swing_width':
        return EngineerParameterPresentation(
          label: welding ? l10n.paramScanWidth : l10n.swingWidthLabel,
        );
      case 'process.wire_feeding_speed':
        return EngineerParameterPresentation(label: l10n.paramWireFeedSpeed);
      case 'process.light_off_delay':
        return EngineerParameterPresentation(label: l10n.paramLaserOffDelay);
      case 'process.back_draw_length':
        return EngineerParameterPresentation(label: l10n.paramRetractLength);
      case 'process.back_draw_speed':
        return EngineerParameterPresentation(label: l10n.paramRetractSpeed);
      case 'process.wire_filling_length':
        return EngineerParameterPresentation(label: l10n.paramRefeedLength);
      case 'process.wire_filling_delay':
        return EngineerParameterPresentation(label: l10n.paramRefeedDelay);
      default:
        return EngineerParameterPresentation(
          label: localizedProcessParameterLabel(l10n, key),
        );
    }
  }
}
