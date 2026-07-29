import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
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
    final headers = <(String, double)>[
      (l10n.processVideoRecordingTime, 232),
      (l10n.processVideoWorkMode, 232),
      (l10n.processVideoMaterial, 205),
      (l10n.processVideoDuration, 130),
      (l10n.processVideoOperations, 0),
    ];

    return Column(
      children: [
        // lws-ui `@drawable/video_process_table_head_bg` — horizontal center glow.
        Container(
          margin: const EdgeInsets.fromLTRB(_leftInset, 0, _rightInset, 0),
          padding: const EdgeInsets.fromLTRB(0, _headerTop, 0, _headerBottom),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0x006C6C6C),
                Color(0xFF636385),
                Color(0x006C6C6C),
              ],
            ),
          ),
          child: Row(
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
                          fontSize: 22,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    l10n.processVideoLoadedCount(
                                      _rows.length,
                                      _total,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
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
                              onDelete: () => unawaited(_delete(row)),
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

  static const _columnGap = VideosTabState._columnGap;

  @override
  Widget build(BuildContext context) {
    final cells = <({String text, double width, int maxLines})>[
      (
        text: ProcessVideoFormat.recordingTime(record),
        width: 232,
        maxLines: 1,
      ),
      (
        text: ProcessVideoFormat.workMode(record.processType),
        width: 232,
        maxLines: 2,
      ),
      (
        text: ProcessVideoFormat.material(record),
        width: 205,
        maxLines: 1,
      ),
      (
        text: ProcessVideoFormat.duration(record.durationMs),
        width: 130,
        maxLines: 1,
      ),
    ];
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
                    child: Text(
                      cells[i].text,
                      maxLines: cells[i].maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: cells[i].maxLines > 1 ? 1.15 : 1.0,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: TextButton(
                      onPressed: onDelete,
                      child: Text(deleteLabel),
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
