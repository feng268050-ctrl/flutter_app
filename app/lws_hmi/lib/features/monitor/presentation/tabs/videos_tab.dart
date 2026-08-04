import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
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

typedef ProcessVideoUploadInvoker = Future<bool> Function(
  String videoId, {
  ProcessVideoUploadListener? listener,
});

/// lws-ui `fragment_process_video` — local recordings list with Upload.
///
/// Body uses Material [DataTable] under the column header strip.
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
  static const _horizontalInset = 24.0;

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

  TextStyle _headingStyle(BuildContext context) =>
      context.hmiTypography.sectionTitle.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      );

  TextStyle _cellStyle(BuildContext context) =>
      context.hmiTypography.caption.copyWith(
        color: Colors.white,
        height: 1.15,
      );

  List<DataColumn> _columns(AppLocalizations l10n) => [
        DataColumn(
          label: Text(
            l10n.processVideoRecordingTime,
            textAlign: TextAlign.center,
          ),
        ),
        DataColumn(
          label: Text(
            l10n.processVideoWorkMode,
            textAlign: TextAlign.center,
          ),
        ),
        DataColumn(
          label: Text(
            l10n.processVideoMaterial,
            textAlign: TextAlign.center,
          ),
        ),
        DataColumn(
          label: Text(
            l10n.processVideoDuration,
            textAlign: TextAlign.center,
          ),
        ),
        DataColumn(
          label: Text(
            l10n.processVideoOperations,
            textAlign: TextAlign.center,
          ),
        ),
      ];

  DataRow _dataRow(
    BuildContext context,
    ProcessVideoRecord row,
    AppLocalizations l10n,
  ) {
    final typography = context.hmiTypography;
    return DataRow(
      onSelectChanged: (_) => unawaited(_openDetail(row)),
      cells: [
        DataCell(
          Text(
            ProcessVideoFormat.recordingTime(row),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            ProcessVideoFormat.workMode(row.processType, l10n),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            ProcessVideoFormat.material(row, l10n),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            ProcessVideoFormat.duration(row.durationMs),
            textAlign: TextAlign.center,
          ),
        ),
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              MonitorFrostActionButton(
                variant: CyberButtonVariant.standard,
                onPressed: _canUpload(row)
                    ? () => unawaited(_upload(row))
                    : null,
                child: Text(
                  l10n.processVideoUpload,
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              MonitorFrostActionButton(
                variant: CyberButtonVariant.secondary,
                onPressed: () => unawaited(_delete(row)),
                child: Text(
                  l10n.deleteText,
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CyberColors.buttonSecondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themedTable({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required List<DataRow> rows,
  }) {
    return Theme(
      data: theme.copyWith(
        dataTableTheme: DataTableThemeData(
          headingTextStyle: _headingStyle(context).copyWith(
            fontSize: context.hmiTypography.caption.fontSize,
          ),
          dataTextStyle: _cellStyle(context),
          dividerThickness: 1,
          headingRowColor: WidgetStateProperty.all(Colors.transparent),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          headingRowHeight: 48,
          dataRowMinHeight: 64,
          dataRowMaxHeight: 88,
        ),
        dividerColor: const Color(0x33FFFFFF),
      ),
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 24,
        horizontalMargin: 8,
        columns: _columns(l10n),
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header stays visible with zero recordings.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _horizontalInset,
                            8,
                            _horizontalInset,
                            0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SizedBox(
                                width: constraints.maxWidth,
                                child: _themedTable(
                                  context: context,
                                  theme: theme,
                                  l10n: l10n,
                                  rows: const [],
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(child: _EmptyState(l10n: l10n)),
                      ],
                    )
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tableWidth =
                                constraints.maxWidth - _horizontalInset * 2;
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                _horizontalInset,
                                8,
                                _horizontalInset,
                                16,
                              ),
                              child: SizedBox(
                                width: tableWidth,
                                child: _themedTable(
                                  context: context,
                                  theme: theme,
                                  l10n: l10n,
                                  rows: [
                                    for (final row in _rows)
                                      _dataRow(context, row, l10n),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
        if (!_loading && _rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.processVideoLoadedCount(_rows.length, _total),
              style: context.hmiTypography.technicalMeta.copyWith(
                color: Colors.white38,
              ),
            ),
          )
        else
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
            style: context.hmiTypography.body.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.processVideoEmptySubtitle,
            style: context.hmiTypography.caption.copyWith(
              color: Colors.white38,
            ),
          ),
        ],
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
