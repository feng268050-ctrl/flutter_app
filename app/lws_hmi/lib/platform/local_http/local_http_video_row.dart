import 'package:lws_hmi/features/process_video/application/process_video_cloud_metadata.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// LAN `:5580` video row shape (lws-ui `DeviceWsVideoListPayload.voToRow`).
abstract final class LocalHttpVideoRow {
  static Map<String, Object?> fromRecord(ProcessVideoRecord r) => {
        'videoId': r.videoId,
        'processType': r.processType.wireValue,
        'materialType': r.materialType?.storageValue,
        'fileSize': r.fileSize,
        'duration': r.durationMs,
        'createTime': r.createTimeMs,
        'resolution': r.resolution,
        'uploadStatus': r.uploadStatus,
        'uploadProgress': r.uploadProgress,
        'coverUrl': r.coverUrl,
        'videoUrl': r.videoUrl,
        'processParameters': ProcessVideoCloudMetadata.processParametersObject(r),
      };
}
