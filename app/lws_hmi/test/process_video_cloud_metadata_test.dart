import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/application/process_video_cloud_metadata.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

void main() {
  test('uploadVideoAndProcessDataBody matches lws-ui ProcessParamsVideo', () {
    final row = ProcessVideoRecord(
      videoId: 'vid-1',
      videoPath: '/Videos/20260811/rec.mp4',
      processType: ProcessType.continuousWelding,
      materialType: MaterialType.stainlessSteel,
      processParametersJson: ProcessVideoSnapshot(
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.stainlessSteel,
        thickness: 0.5,
        parameters: ProcessParameters(const {
          'process.laser_power': 70,
          'process.swing_frequency': 100,
        }),
      ).toJsonString(),
      fileSize: 1000,
      durationMs: 5000,
      resolution: '1920x1080',
      createTimeMs: 1786440000000,
    );

    final body = ProcessVideoCloudMetadata.uploadVideoAndProcessDataBody(
      row: row,
      deviceSn: 'SN001',
      coverUrl: 'https://cdn.example/cover.jpg',
    );

    final params = body['processParametersData'] as Map<String, Object?>;
    expect(params['laserPower'], 70);
    expect(params['swingFrequency'], 100);
    expect(params['thickness'], 0.5);

    final video = body['processVideo'] as Map<String, Object?>;
    expect(video['deviceSn'], 'SN001');
    expect(video['coverUrl'], 'https://cdn.example/cover.jpg');
    expect(video['videoName'], 'rec.mp4');
    expect(video['processType'], ProcessType.continuousWelding.wireValue);
  });

  test('processParametersJson wire field is mobile-compatible', () {
    final row = ProcessVideoRecord(
      videoId: 'vid-2',
      videoPath: '/a.mp4',
      processType: ProcessType.continuousWelding,
      processParametersJson: ProcessVideoSnapshot(
        processType: ProcessType.continuousWelding,
        parameters: ProcessParameters(const {'process.laser_power': 42}),
      ).toJsonString(),
      fileSize: 1,
      durationMs: 1,
      createTimeMs: 1,
    );
    expect(
      ProcessVideoCloudMetadata.processParametersJson(row),
      contains('"laserPower":42'),
    );
  });
}
