import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Which catalog keys (and meta fields) appear for each engineer process type.
///
/// Mirrors lws-ui fragment field sets, without porting Android visibility XML.
abstract final class EngineerParameterVisibility {
  static const _weldingShared = <String>[
    'process.laser_power',
    'process.blowing_delay',
    'process.gas_off_delay',
    'process.swing_frequency',
    'process.swing_width',
    'process.light_off_delay',
  ];

  static const _continuousOnly = <String>[
    'process.power_ramp_up_duration',
    'process.power_ramp_down_duration',
    'process.wire_feeding_speed',
    'process.back_draw_length',
    'process.back_draw_speed',
    'process.wire_filling_length',
    'process.wire_filling_delay',
  ];

  static const _spotOnly = <String>[
    'process.spot_welding_interval',
    'process.spot_welding_duration',
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
        return [..._weldingShared, ..._continuousOnly];
      case ProcessType.spotWelding:
        return [..._weldingShared, ..._spotOnly];
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
