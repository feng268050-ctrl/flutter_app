import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Supplies frozen process context for Record Work encode start / save.
///
/// Owned by Quick / Engineer pages (they hold live process UI state).
abstract interface class ProcessVideoSnapshotSource {
  /// Capture at encode start (required fallback at save).
  ProcessVideoSnapshot? capture();

  /// Prefer live params when still attached and [start.processType] matches.
  ProcessVideoSnapshot resolveAtSave(ProcessVideoSnapshot start);
}

/// Default resolver: live capture when process type matches, else [start].
final class CallbackProcessVideoSnapshotSource
    implements ProcessVideoSnapshotSource {
  CallbackProcessVideoSnapshotSource(this._capture);

  final ProcessVideoSnapshot? Function() _capture;

  @override
  ProcessVideoSnapshot? capture() => _capture();

  @override
  ProcessVideoSnapshot resolveAtSave(ProcessVideoSnapshot start) {
    final live = _capture();
    if (live != null && live.processType == start.processType) {
      return live;
    }
    return start;
  }
}
