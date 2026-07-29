import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Durable index of local process videos (Monitor list/detail; no upload).
abstract interface class ProcessVideoRepository {
  /// Opens the DB (create-if-missing). Soft-fail implementations may no-op.
  Future<void> open();

  Future<ProcessVideoRecord> insert(ProcessVideoRecord record);

  /// Newest-first page. [offset] skips newer rows.
  Future<List<ProcessVideoRecord>> list({int limit = 10, int offset = 0});

  Future<int> count();

  Future<ProcessVideoRecord?> getById(int id);

  /// Deletes the index row and best-effort deletes [ProcessVideoRecord.videoPath].
  Future<bool> deleteById(int id);

  Future<void> close();
}
