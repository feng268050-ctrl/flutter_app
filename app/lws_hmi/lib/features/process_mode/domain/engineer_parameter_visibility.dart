import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Which catalog keys (and meta fields) appear for each engineer process type.
///
/// Row order matches lws-ui `fragment_engineer_welding` / wash layouts.
abstract final class EngineerParameterVisibility {
  static const _continuousWelding = <String>[
    'process.blowing_delay',
    'process.power_ramp_up_duration',
    'process.laser_power',
    'process.power_ramp_down_duration',
    'process.gas_off_delay',
    'process.swing_frequency',
    'process.swing_width',
    'process.wire_feeding_speed',
    'process.light_off_delay',
    'process.back_draw_length',
    'process.back_draw_speed',
    'process.wire_filling_length',
    'process.wire_filling_delay',
  ];

  static const _spotWelding = <String>[
    'process.spot_welding_interval',
    'process.spot_welding_duration',
    'process.blowing_delay',
    'process.laser_power',
    'process.gas_off_delay',
    'process.swing_frequency',
    'process.swing_width',
    'process.light_off_delay',
  ];

  static const _cleaning = <String>[
    'process.laser_power',
    'process.swing_frequency',
    'process.swing_width',
    'process.blowing_delay',
    'process.gas_off_delay',
    'process.power_ramp_up_duration',
    'process.power_ramp_down_duration',
  ];

  static const _cutting = <String>[
    'process.laser_power',
    'process.blowing_delay',
    'process.gas_off_delay',
    'process.power_ramp_up_duration',
    'process.power_ramp_down_duration',
  ];

  static List<String> parameterKeysFor(ProcessType type) {
    switch (type) {
      case ProcessType.continuousWelding:
        return List<String>.from(_continuousWelding);
      case ProcessType.spotWelding:
        return List<String>.from(_spotWelding);
      case ProcessType.weldCleaning:
      case ProcessType.wideCleaning:
        return List<String>.from(_cleaning);
      case ProcessType.handCutting:
      case ProcessType.cncCutting:
        return List<String>.from(_cutting);
    }
  }

  static bool showsThickness(ProcessType type) => !type.isCleaning;

  static bool showsMaterial(ProcessType type) => true;
}
