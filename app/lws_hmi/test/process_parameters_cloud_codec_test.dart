import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_cloud_codec.dart';

void main() {
  group('ProcessParametersCloudCodec', () {
    test('unwraps bare and enveloped process param', () {
      final bare = ProcessParametersCloudCodec.unwrapParamPayload({
        'name': 'A',
        'laserPower': 70,
        'processType': 0,
      });
      expect(bare?['laserPower'], 70);

      final env = ProcessParametersCloudCodec.unwrapParamPayload({
        'msgType': 1,
        'data': {'name': 'B', 'laserPower': 50},
      });
      expect(env?['name'], 'B');
    });

    test('unwraps process lib dataList', () {
      final lib = ProcessParametersCloudCodec.unwrapLibPayload({
        'versionCode': 9,
        'dataList': [
          {'name': 'q1', 'laserPower': 10, 'processType': 0, 'materialType': 1},
        ],
      });
      expect(lib?.versionCode, 9);
      expect(lib?.dataList.length, 1);
    });

    test('maps cloud fields to process.* keys', () {
      final params = ProcessParametersCloudCodec.parametersFromCloud({
        'laserPower': 80,
        'wireFeedSpeed': 12.5,
        'perforationDuration': 1.5,
      });
      expect(params.values['process.laser_power'], 80);
      expect(params.values['process.wire_feeding_speed'], 12.5);
      expect(params.values['process.piercing_duration'], 1500);
    });

    test('builds user preset from cloud json', () {
      final preset = ProcessParametersCloudCodec.presetFromCloud(
        {
          'name': 'Cloud',
          'processType': 1,
          'materialType': 2,
          'laserPower': 40,
        },
        kind: ProcessPresetKind.user,
        source: 'cloud',
        isBuiltin: false,
        uuid: 'u-1',
      );
      expect(preset.name, 'Cloud');
      expect(preset.processType, ProcessType.spotWelding);
      expect(preset.materialType, MaterialType.carbonSteel);
      expect(preset.parameters.values['process.laser_power'], 40);
    });
  });
}
