import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_parameter_presentation.dart';

void main() {
  test('continuous welding shows T2/T3/T4/P suffixes', () {
    const type = ProcessType.continuousWelding;
    expect(
      EngineerParameterPresentation.forKey(
        'process.power_ramp_up_duration',
        type,
      ).suffix,
      '(T2)',
    );
    expect(
      EngineerParameterPresentation.forKey(
        'process.power_ramp_down_duration',
        type,
      ).suffix,
      '(T3)',
    );
    expect(
      EngineerParameterPresentation.forKey('process.gas_off_delay', type)
          .suffix,
      '(T4)',
    );
    expect(
      EngineerParameterPresentation.forKey('process.laser_power', type).suffix,
      '(P)',
    );
    expect(
      EngineerParameterPresentation.forKey('process.blowing_delay', type)
          .suffix,
      isNull,
    );
  });

  test('spot welding shows T1/T2 on interval/duration, not T4 on post-flow',
      () {
    const type = ProcessType.spotWelding;
    expect(
      EngineerParameterPresentation.forKey(
        'process.spot_welding_interval',
        type,
      ).suffix,
      '(T1)',
    );
    expect(
      EngineerParameterPresentation.forKey(
        'process.spot_welding_duration',
        type,
      ).suffixColor,
      const Color(0xFFFD7632),
    );
    expect(
      EngineerParameterPresentation.forKey('process.gas_off_delay', type)
          .suffix,
      isNull,
    );
  });
}
