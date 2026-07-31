import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/features/status_bar/product_top_tabs.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `fragment_process_video` — local recordings list (no upload).
class VideosTab extends StatefulWidget {
  const VideosTab({
    super.key,
    this.repository,
  });

  /// Injected in widget tests; production uses [SqliteProcessVideoRepository].
  final ProcessVideoRepository? repository;

  static const pageSize = 10;

  @override
  State<VideosTab> createState() => VideosTabState();
}

@visibleForTesting
class VideosTabState extends State<VideosTab> {
  /// Match Monitor tab hairline / card inset ([ProductTopTabs.dividerInset]).
  static const _leftInset = ProductTopTabs.dividerInset;
  static const _rightInset = ProductTopTabs.dividerInset;

  /// Shared column widths (design dp @ 1280) — header and data must match.
  static const _colRecordingTime = 232.0;
  static const _colProcess = 232.0;
  static const _colMaterial = 205.0;
  static const _colDuration = 130.0;
  static const _columnGap = 26.0;

  /// Original table-head vertical padding (lws-ui head band height).
  static const _headerTop = 35.0;
  static const _headerBottom = 32.0;

  /// Row band height (design): vertical rhythm between video entries.
  static const _rowMinHeight = 86.0;

  /// Subtle lift over page chrome (not a gradient plate).
  static const _headerFill = Color(0x1AFFFFFF);
  static const _headerDivider = Color(0x55FFFFFF);
  static const _rowDivider = Color(0x22FFFFFF);

  late final ProcessVideoRepository _repo =
      widget.repository ?? SqliteProcessVideoRepository();
  final List<ProcessVideoRecord> _rows = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

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

  Future<bool> _confirmDelete(ProcessVideoRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.processVideoDeleteConfirmTitle),
        content: Text(l10n.processVideoDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteText),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(ProcessVideoRecord record) async {
    if (record.id == null) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    if (!await _confirmDelete(record)) {
      return;
    }
    await _repo.deleteById(record.id!);
    await _reload();
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_leftInset, 0, _rightInset, 0),
          child: _VideoTableHeader(
            scale: scale,
            labels: (
              recordingTime: l10n.processVideoRecordingTime,
              process: l10n.processVideoWorkMode,
              material: l10n.processVideoMaterial,
              duration: l10n.processVideoDuration,
              operations: l10n.processVideoOperations,
            ),
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
                            0,
                            _rightInset,
                            8,
                          ),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return _VideoRow(
                              record: row,
                              scale: scale,
                              onOpen: () => unawaited(_openDetail(row)),
                              onDelete: () => unawaited(_delete(row)),
                              deleteLabel: l10n.deleteText,
                            );
                          },
                        ),
                      ),
                    ),
        ),
        // Pinned footer: loaded / total (pagination progress).
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
            child: Text(
              l10n.processVideoLoadedCount(_rows.length, _total),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Static column labels — not interactive (no Tab / sort / press state).
final class _VideoTableHeader extends StatelessWidget {
  const _VideoTableHeader({
    required this.scale,
    required this.labels,
  });

  final double scale;
  final ({
    String recordingTime,
    String process,
    String material,
    String duration,
    String operations,
  }) labels;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    return ColoredBox(
      color: VideosTabState._headerFill,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              VideosTabState._headerTop,
              0,
              VideosTabState._headerBottom,
            ),
            child: Row(
              children: [
                _HeaderCell(
                  width: VideosTabState._colRecordingTime * scale,
                  gap: VideosTabState._columnGap * scale,
                  label: labels.recordingTime,
                  style: style,
                ),
                _HeaderCell(
                  width: VideosTabState._colProcess * scale,
                  gap: VideosTabState._columnGap * scale,
                  label: labels.process,
                  style: style,
                ),
                _HeaderCell(
                  width: VideosTabState._colMaterial * scale,
                  gap: VideosTabState._columnGap * scale,
                  label: labels.material,
                  style: style,
                ),
                _HeaderCell(
                  width: VideosTabState._colDuration * scale,
                  gap: VideosTabState._columnGap * scale,
                  label: labels.duration,
                  style: style,
                ),
                Expanded(
                  child: Text(
                    labels.operations,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
          const ColoredBox(
            color: VideosTabState._headerDivider,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ],
      ),
    );
  }
}

final class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.gap,
    required this.label,
    required this.style,
  });

  final double width;
  final double gap;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: gap),
      child: SizedBox(
        width: width,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
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
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.processVideoEmptySubtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
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
    required this.onDelete,
    required this.deleteLabel,
  });

  final ProcessVideoRecord record;
  final double scale;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final cells = <({String text, double width, int maxLines})>[
      (
        text: ProcessVideoFormat.recordingTime(record),
        width: VideosTabState._colRecordingTime,
        maxLines: 1,
      ),
      (
        text: ProcessVideoFormat.workMode(record.processType),
        width: VideosTabState._colProcess,
        maxLines: 2,
      ),
      (
        text: ProcessVideoFormat.material(record),
        width: VideosTabState._colMaterial,
        maxLines: 1,
      ),
      (
        text: ProcessVideoFormat.duration(record.durationMs),
        width: VideosTabState._colDuration,
        maxLines: 1,
      ),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: VideosTabState._rowMinHeight,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: VideosTabState._rowDivider),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final cell in cells)
                  Padding(
                    padding: EdgeInsets.only(
                      right: VideosTabState._columnGap * scale,
                    ),
                    child: SizedBox(
                      width: cell.width * scale,
                      child: Text(
                        cell.text,
                        textAlign: TextAlign.center,
                        maxLines: cell.maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: cell.maxLines > 1 ? 1.15 : 1.0,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: TextButton(
                      onPressed: onDelete,
                      child: Text(deleteLabel),
                    ),
                  ),
                ),
              ],
            ),
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
