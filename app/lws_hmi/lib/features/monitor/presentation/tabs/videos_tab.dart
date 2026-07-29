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
      (l10n.processVideoWorkMode, 196),
      (l10n.processVideoMaterial, 229),
      (l10n.processVideoDuration, 157),
      (l10n.processVideoOperations, 0),
    ];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 48, 0),
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 24),
          decoration: BoxDecoration(
            color: const Color(0x332E3653),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (label, width) in headers)
                if (width > 0)
                  SizedBox(
                    width: width * scale,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                          padding: const EdgeInsets.fromLTRB(24, 8, 48, 16),
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

  @override
  Widget build(BuildContext context) {
    final cells = <(String, double)>[
      (ProcessVideoFormat.recordingTime(record), 232),
      (ProcessVideoFormat.workMode(record.processType), 196),
      (ProcessVideoFormat.material(record), 229),
      (ProcessVideoFormat.duration(record.durationMs), 157),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x222E3653),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              for (final (text, width) in cells)
                SizedBox(
                  width: width * scale,
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
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
