import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_cloud_codec.dart';

/// Cloud / mobile wire shapes for process-video metadata (lws-ui parity).
abstract final class ProcessVideoCloudMetadata {
  /// `processParametersJson` for WS `video.metadata` / list rows.
  static String? processParametersJson(ProcessVideoRecord row) =>
      ProcessParametersCloudCodec.processParametersJsonFromSnapshot(row.snapshot);

  /// Parsed object for LAN `GET /v1/videos` (`processParameters` key).
  static Map<String, Object?>? processParametersObject(ProcessVideoRecord row) {
    final snapshot = row.snapshot;
    if (snapshot == null) {
      return null;
    }
    return ProcessParametersCloudCodec.toCloudMap(snapshot);
  }

  /// Body for `POST videoMange/video/uploadVideoAndProcessData`.
  static Map<String, Object?> uploadVideoAndProcessDataBody({
    required ProcessVideoRecord row,
    required String deviceSn,
    required String coverUrl,
    String? videoUrl,
  }) {
    final snapshot = row.snapshot;
    return {
      'processParametersData': snapshot != null
          ? ProcessParametersCloudCodec.toCloudMap(snapshot)
          : <String, Object?>{},
      'processVideo': {
        'coverUrl': coverUrl,
        if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
        'videoDuration': row.durationMs,
        'videoName': _basename(row.videoPath),
        'recordingTime': row.createTimeMs,
        'processType': row.processType.wireValue,
        'deviceSn': deviceSn,
      },
    };
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }
}
