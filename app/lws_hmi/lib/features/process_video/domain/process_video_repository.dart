import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Query filters for cloud WS / LAN video list (lws-ui ProcessVideoQueryService).
final class ProcessVideoListQuery {
  const ProcessVideoListQuery({
    this.page = 1,
    this.pageSize = 10,
    this.processType,
    this.materialType,
    this.startDateYmd,
    this.endDateYmd,
    this.orderAsc = false,
    this.uploadStatus,
    this.excludeNotInitiatedWhenUploadStatusUnset = true,
  });

  final int page;
  final int pageSize;
  final int? processType;
  final int? materialType;
  /// `yyyy-MM-dd` inclusive start (device local calendar).
  final String? startDateYmd;
  final String? endDateYmd;
  final bool orderAsc;
  final int? uploadStatus;
  final bool excludeNotInitiatedWhenUploadStatusUnset;
}

final class ProcessVideoListPage {
  const ProcessVideoListPage({required this.list, required this.total});
  final List<ProcessVideoRecord> list;
  final int total;
}

/// Durable index of local process videos (Monitor list/detail; cloud upload).
abstract interface class ProcessVideoRepository {
  /// Opens the DB (create-if-missing). Soft-fail implementations may no-op.
  Future<void> open();

  Future<ProcessVideoRecord> insert(ProcessVideoRecord record);

  /// Newest-first page. [offset] skips newer rows.
  Future<List<ProcessVideoRecord>> list({int limit = 10, int offset = 0});

  /// Filtered / paginated list for `command.video_list_request`.
  Future<ProcessVideoListPage> query(ProcessVideoListQuery q);

  Future<int> count();

  Future<ProcessVideoRecord?> getById(int id);

  Future<ProcessVideoRecord?> findByVideoId(String videoId);

  Future<bool> updateUploadState({
    required String videoId,
    required int uploadStatus,
    required int uploadProgress,
    String? coverUrl,
    String? videoUrl,
  });

  /// Deletes the index row and best-effort deletes [ProcessVideoRecord.videoPath].
  Future<bool> deleteById(int id);

  /// Deletes by business [videoId] (LAN/WS path key).
  Future<bool> deleteByVideoId(String videoId);

  Future<void> close();
}
