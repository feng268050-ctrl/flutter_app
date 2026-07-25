import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

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
  ) {
    final welding = processType == ProcessType.continuousWelding ||
        processType == ProcessType.spotWelding;
    final continuous = processType == ProcessType.continuousWelding;

    switch (key) {
      case 'process.spot_welding_interval':
        return const EngineerParameterPresentation(
          label: 'Spot Weld Interval',
          suffix: '(T1)',
          suffixColor: _t1Blue,
        );
      case 'process.spot_welding_duration':
        return const EngineerParameterPresentation(
          label: 'Spot Weld Duration',
          suffix: '(T2)',
          suffixColor: _t3Weld,
        );
      case 'process.blowing_delay':
        return const EngineerParameterPresentation(label: 'Gas Pre-Flow');
      case 'process.power_ramp_up_duration':
        return EngineerParameterPresentation(
          label: 'Ramp-Up Time',
          suffix: continuous ? '(T2)' : null,
          suffixColor: continuous ? _t2Orange : null,
        );
      case 'process.laser_power':
        return EngineerParameterPresentation(
          label: 'Laser Power',
          suffix: welding ? '(P)' : null,
        );
      case 'process.power_ramp_down_duration':
        return EngineerParameterPresentation(
          label: 'Ramp-Down Time',
          suffix: continuous ? '(T3)' : null,
          suffixColor: continuous ? _t3Weld : null,
        );
      case 'process.gas_off_delay':
        return EngineerParameterPresentation(
          label: 'Gas Post-Flow',
          suffix: continuous ? '(T4)' : null,
          suffixColor: continuous ? _t4Blue : null,
        );
      case 'process.swing_frequency':
        return const EngineerParameterPresentation(label: 'Scan Frequency');
      case 'process.swing_width':
        return EngineerParameterPresentation(
          label: welding ? 'Scan Width' : 'Swing width',
        );
      case 'process.wire_feeding_speed':
        return const EngineerParameterPresentation(label: 'Wire Feed Speed');
      case 'process.light_off_delay':
        return const EngineerParameterPresentation(label: 'Laser-Off Delay');
      case 'process.back_draw_length':
        return const EngineerParameterPresentation(label: 'Retract Length');
      case 'process.back_draw_speed':
        return const EngineerParameterPresentation(label: 'Retract Speed');
      case 'process.wire_filling_length':
        return const EngineerParameterPresentation(label: 'Re-feed Length');
      case 'process.wire_filling_delay':
        return const EngineerParameterPresentation(label: 'Re-feed Delay');
      default:
        final spec = ProcessParameterCatalog.byKey[key];
        return EngineerParameterPresentation(
          label: spec?.label ?? key,
        );
    }
  }
}
