import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Monitor Videos Upload enablement (lws-ui process-video list).
abstract final class ProcessVideoUploadGating {
  /// Upload is offered but inactive when already at status 3 or this row is
  /// already the in-flight upload target.
  static bool canStartUpload({
    required int uploadStatus,
    required bool isUploadingThisRow,
  }) =>
      uploadStatus != ProcessVideoUploadStatus.videoUploaded &&
      !isUploadingThisRow;
}
