import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/process_video/application/process_video_cloud_upload_coordinator.dart';
import 'package:lws_hmi/features/process_video/application/process_video_upload_gating.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_dialogs.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';

typedef ProcessVideoUploadInvoker = Future<bool> Function(
  String videoId, {
  ProcessVideoUploadListener? listener,
});

/// lws-ui `fragment_process_video` — local recordings list with Upload.
class VideosTab extends StatefulWidget {
  const VideosTab({
    super.key,
    this.repository,
    this.uploadVideo,
  });

  /// Injected in widget tests; production uses [SqliteProcessVideoRepository].
  final ProcessVideoRepository? repository;

  /// Injected in widget tests; production uses [CloudLocalRuntimeScope].
  final ProcessVideoUploadInvoker? uploadVideo;

  static const pageSize = 10;

  @override
  State<VideosTab> createState() => VideosTabState();
}

@visibleForTesting
class VideosTabState extends State<VideosTab> {
  static const _leftInset = 24.0;
  static const _rightInset = 58.0;
  static const _columnGap = 26.0;
  static const _headerTop = 35.0;
  static const _headerBottom = 32.0;
  static const _rowTop = 35.0;
  static const _rowBottom = 33.0;

  late final ProcessVideoRepository _repo =
      widget.repository ?? SqliteProcessVideoRepository();
  final List<ProcessVideoRecord> _rows = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _uploadingVideoId;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    if (widget.repository == null) {
      unawaited(_repo.close());
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      await _repo.open();
      final total = await _repo.count();
      final page = await _repo.list(limit: VideosTab.pageSize, offset: 0);
      if (!mounted) {
        return;
      }
      setState(() {
        _total = total;
        _rows
          ..clear()
          ..addAll(page);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _total = 0;
        _rows.clear();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _rows.length >= _total) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.list(
        limit: VideosTab.pageSize,
        offset: _rows.length,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows.addAll(page);
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  bool _isUploadingRow(ProcessVideoRecord record) {
    if (_uploadingVideoId == record.videoId) {
      return true;
    }
    final runtime = CloudLocalRuntimeScope.maybeOf(context);
    return runtime?.processVideoUpload.isUploading(record.videoId) ?? false;
  }

  bool _canUpload(ProcessVideoRecord record) =>
      ProcessVideoUploadGating.canStartUpload(
        uploadStatus: record.uploadStatus,
        isUploadingThisRow: _isUploadingRow(record),
      );

  ProcessVideoUploadInvoker? _resolveUploader() {
    if (widget.uploadVideo != null) {
      return widget.uploadVideo;
    }
    final runtime = CloudLocalRuntimeScope.maybeOf(context);
    if (runtime == null) {
      return null;
    }
    return runtime.uploadProcessVideo;
  }

  Future<bool> _confirmDelete() =>
      showProcessVideoDeleteDialog(context: context);

  Future<void> _delete(ProcessVideoRecord record) async {
    if (record.id == null) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    if (!await _confirmDelete()) {
      return;
    }
    await _repo.deleteById(record.id!);
    await _reload();
  }

  Future<void> _upload(ProcessVideoRecord record) async {
    CyberClickSoundRegistry.playClick();
    final l10n = AppLocalizations.of(context)!;
    if (record.uploadStatus == ProcessVideoUploadStatus.videoUploaded) {
      _toast(l10n.processVideoAlreadyUploaded);
      return;
    }
    if (!_canUpload(record)) {
      return;
    }
    if (!await showProcessVideoUploadDialog(context: context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final uploader = _resolveUploader();
    if (uploader == null) {
      _toast(l10n.processVideoUploadFailed);
      return;
    }

    setState(() => _uploadingVideoId = record.videoId);

    final phase = ValueNotifier<_UploadUiPhase>(_UploadUiPhase.cover);
    final percent = ValueNotifier<int>(0);
    var dialogOpen = true;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final dlgL10n = AppLocalizations.of(ctx)!;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(dlgL10n.processVideoUpload),
              content: AnimatedBuilder(
                animation: Listenable.merge([phase, percent]),
                builder: (_, __) {
                  final label = phase.value == _UploadUiPhase.cover
                      ? dlgL10n.processVideoUploadingCover
                      : dlgL10n.processVideoUploadingVideo(percent.value);
                  final progress = phase.value == _UploadUiPhase.cover
                      ? null
                      : (percent.value.clamp(0, 100) / 100.0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(label),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ).whenComplete(() => dialogOpen = false),
    );

    final listener = _UploadDialogListener(
      onCover: () => phase.value = _UploadUiPhase.cover,
      onProgress: (p) {
        phase.value = _UploadUiPhase.video;
        percent.value = p;
      },
    );

    var ok = false;
    var errorMessage = l10n.processVideoUploadFailed;
    try {
      ok = await uploader(record.videoId, listener: listener);
      if (listener.errorMessage != null && listener.errorMessage!.isNotEmpty) {
        errorMessage = _mapUploadError(l10n, listener.errorMessage!);
      }
    } catch (_) {
      ok = false;
    }

    if (mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    phase.dispose();
    percent.dispose();

    if (!mounted) {
      return;
    }
    setState(() => _uploadingVideoId = null);
    await _reload();
    _toast(ok ? l10n.processVideoUploadDone : errorMessage);
  }

  String _mapUploadError(AppLocalizations l10n, String code) {
    if (code == 'already_uploaded') {
      return l10n.processVideoAlreadyUploaded;
    }
    return l10n.processVideoUploadFailed;
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDetail(ProcessVideoRecord record) async {
    if (record.id == null) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    final deleted = await Navigator.of(context).pushNamed(
      AppRoutes.processVideoDetail,
      arguments: ProcessVideoDetailArgs(
        recordId: record.id!,
        repository: _repo,
      ),
    );
    if (deleted == true || !mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scale =
        (MediaQuery.sizeOf(context).width / 1280).clamp(0.55, 1.0);
    final headers = <(String, double)>[
      (l10n.processVideoRecordingTime, 232),
      (l10n.processVideoWorkMode, 232),
      (l10n.processVideoMaterial, 205),
      (l10n.processVideoDuration, 130),
      (l10n.processVideoOperations, 0),
    ];

    return Column(
      children: [
        // Column labels + center→sides fade hairline (no header fill).
        Padding(
          padding: const EdgeInsets.fromLTRB(_leftInset, _headerTop, _rightInset, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (final (label, width) in headers)
                    if (width > 0)
                      Padding(
                        padding: EdgeInsets.only(
                          right: _columnGap * scale,
                        ),
                        child: SizedBox(
                          width: width * scale,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: AppTypography.sectionTitleSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppTypography.sectionTitleSize,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                ],
              ),
              SizedBox(height: _headerBottom),
              const SizedBox(
                height: 1,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0xB3FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? _EmptyState(l10n: l10n)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                            n.metrics.maxScrollExtent - 80) {
                          unawaited(_loadMore());
                        }
                        return false;
                      },
                      child: RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            _leftInset,
                            8,
                            _rightInset,
                            16,
                          ),
                          itemCount: _rows.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _rows.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    l10n.processVideoLoadedCount(
                                      _rows.length,
                                      _total,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: AppTypography.microSize,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final row = _rows[index];
                            return _VideoRow(
                              record: row,
                              scale: scale,
                              onOpen: () => unawaited(_openDetail(row)),
                              onUpload: () => unawaited(_upload(row)),
                              onDelete: () => unawaited(_delete(row)),
                              uploadEnabled: _canUpload(row),
                              uploadLabel: l10n.processVideoUpload,
                              deleteLabel: l10n.deleteText,
                            );
                          },
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

enum _UploadUiPhase { cover, video }

final class _UploadDialogListener implements ProcessVideoUploadListener {
  _UploadDialogListener({
    required this.onCover,
    required this.onProgress,
  });

  final VoidCallback onCover;
  final ValueChanged<int> onProgress;
  String? errorMessage;

  @override
  void onMetadataPhaseStarted() => onCover();

  @override
  void onVideoProgress(int percent) => onProgress(percent);

  @override
  void onFinishedSuccess() {}

  @override
  void onFinishedError(String message) {
    errorMessage = message;
  }
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            l10n.processVideoEmptyTitle,
            style: const TextStyle(color: Colors.white54, fontSize: AppTypography.bodySize),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.processVideoEmptySubtitle,
            style: const TextStyle(color: Colors.white38, fontSize: AppTypography.captionSize),
          ),
        ],
      ),
    );
  }
}

final class _VideoRow extends StatelessWidget {
  const _VideoRow({
    required this.record,
    required this.scale,
    required this.onOpen,
    required this.onUpload,
    required this.onDelete,
    required this.uploadEnabled,
    required this.uploadLabel,
    required this.deleteLabel,
  });

  final ProcessVideoRecord record;
  final double scale;
  final VoidCallback onOpen;
  final VoidCallback onUpload;
  final VoidCallback onDelete;
  final bool uploadEnabled;
  final String uploadLabel;
  final String deleteLabel;

  static const _columnGap = VideosTabState._columnGap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cells = <({String text, double width, int maxLines})>[
      (
        text: ProcessVideoFormat.recordingTime(record),
        width: 232,
        maxLines: 1,
      ),
      (
        text: ProcessVideoFormat.workMode(record.processType, l10n),
        width: 232,
        maxLines: 2,
      ),
      (
        text: ProcessVideoFormat.material(record, l10n),
        width: 205,
        maxLines: 1,
      ),
      (
        text: ProcessVideoFormat.duration(record.durationMs),
        width: 130,
        maxLines: 1,
      ),
    ];
    final uploadStyle = TextStyle(
      fontSize: AppTypography.bodySize * scale.clamp(0.75, 1.0),
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );
    final deleteStyle = TextStyle(
      fontSize: AppTypography.bodySize * scale.clamp(0.75, 1.0),
      fontWeight: FontWeight.w600,
      color: CyberColors.buttonSecondaryText,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x33FFFFFF)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < cells.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    top: VideosTabState._rowTop,
                    bottom: VideosTabState._rowBottom,
                    right: _columnGap * scale,
                  ),
                  child: SizedBox(
                    width: cells[i].width * scale,
                    // Match header [TextAlign.center] so columns line up.
                    child: Text(
                      cells[i].text,
                      textAlign: TextAlign.center,
                      maxLines: cells[i].maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTypography.captionSize,
                        height: cells[i].maxLines > 1 ? 1.15 : 1.0,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: VideosTabState._rowTop * 0.35,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MonitorFrostActionButton(
                          variant: CyberButtonVariant.standard,
                          onPressed: uploadEnabled ? onUpload : null,
                          child: Text(uploadLabel, style: uploadStyle),
                        ),
                        SizedBox(width: 12 * scale),
                        MonitorFrostActionButton(
                          variant: CyberButtonVariant.secondary,
                          onPressed: onDelete,
                          child: Text(deleteLabel, style: deleteStyle),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route arguments for [AppRoutes.processVideoDetail].
final class ProcessVideoDetailArgs {
  const ProcessVideoDetailArgs({
    required this.recordId,
    this.repository,
  });

  final int recordId;
  final ProcessVideoRepository? repository;
}
