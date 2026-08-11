import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/application/process_video_params_ingest.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

void main() {
  test('normalizes camelCase ProcessParametersData to HMI envelope', () {
    final raw = jsonEncode({
      'id': 804,
      'gear': 1,
      'name': '不锈钢',
      'processType': 0,
      'materialType': 1,
      'materialName': 'Stainless Steel',
      'thickness': 0.5,
      'laserPower': 70,
      'swingFrequency': 100,
      'blowDelay': 500,
      'wireFeedSpeed': 12.5,
      'powerRampUp': 200,
      'powerRampDown': 150,
    });
    final stored = ProcessVideoParamsIngest.normalizeJson(
      raw,
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
    );
    final snap = ProcessVideoSnapshot.tryParseJson(stored);
    expect(snap, isNotNull);
    expect(snap!.thickness, 0.5);
    expect(snap.gear, 1);
    expect(snap.parameters.values['process.laser_power'], 70);
    expect(snap.parameters.values['process.swing_frequency'], 100);
    expect(snap.parameters.values['process.blowing_delay'], 500);
    expect(snap.parameters.values['process.wire_feeding_speed'], 12.5);
  });

  test('keeps HMI envelope parameters intact', () {
    final envelope = ProcessVideoSnapshot(
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
      thickness: 1.0,
      parameters: ProcessParameters(const {
        'process.laser_power': 55,
      }),
    ).toJsonString();
    final stored = ProcessVideoParamsIngest.normalizeJson(
      envelope,
      processType: ProcessType.spotWelding,
      materialType: MaterialType.carbonSteel,
    );
    final snap = ProcessVideoSnapshot.tryParseJson(stored)!;
    expect(snap.processType, ProcessType.continuousWelding);
    expect(snap.parameters.values['process.laser_power'], 55);
  });

  test('empty raw yields minimal envelope from form fields', () {
    final stored = ProcessVideoParamsIngest.normalizeJson(
      '',
      processType: ProcessType.handCutting,
      materialType: MaterialType.aluminumAlloy,
    );
    final snap = ProcessVideoSnapshot.tryParseJson(stored)!;
    expect(snap.processType, ProcessType.handCutting);
    expect(snap.materialType, MaterialType.aluminumAlloy);
    expect(snap.parameters.values, isEmpty);
  });
}
