import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/monitor/presentation/monitor_page.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui `AiVisionVideoChooseActivity` — table pick → [ProcessVideoRecord].
class AiVisionVideoChoosePage extends StatefulWidget {
  const AiVisionVideoChoosePage({super.key, this.repository});

  final ProcessVideoRepository? repository;

  static const pageSize = 20;

  @override
  State<AiVisionVideoChoosePage> createState() =>
      _AiVisionVideoChoosePageState();
}

class _AiVisionVideoChoosePageState extends State<AiVisionVideoChoosePage> {
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
      final page = await _repo.list(
        limit: AiVisionVideoChoosePage.pageSize,
        offset: 0,
      );
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
        limit: AiVisionVideoChoosePage.pageSize,
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

  void _select(ProcessVideoRecord record) {
    Navigator.of(context).pop(record);
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

    return Scaffold(
      backgroundColor: MonitorPage.background,
      appBar: ProductPageStatusBar(
        title: l10n.aiVisionChooseBtn,
        backgroundColor: MonitorPage.background,
        foregroundColor: Colors.white,
        toolbarHeight: WorkModeStatusBarDimens.height,
        backLabel: l10n.aiVisionTitle,
        backAccent: WorkModeAccent.weld,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        children: [
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
                      padding: EdgeInsets.only(right: _columnGap * scale),
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
                    ? Center(
                        child: Text(
                          l10n.processVideoEmptyTitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 80) {
                            unawaited(_loadMore());
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            _leftInset,
                            8,
                            _rightInset,
                            16,
                          ),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return _ChooseRow(
                              record: row,
                              scale: scale,
                              selectLabel: l10n.aiVisionSelectBtn,
                              onSelect: () => _select(row),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

final class _ChooseRow extends StatelessWidget {
  const _ChooseRow({
    required this.record,
    required this.scale,
    required this.selectLabel,
    required this.onSelect,
  });

  final ProcessVideoRecord record;
  final double scale;
  final String selectLabel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cells = <({String text, double width})>[
      (text: ProcessVideoFormat.recordingTime(record), width: 232),
      (text: ProcessVideoFormat.workMode(record.processType), width: 232),
      (text: ProcessVideoFormat.material(record), width: 205),
      (text: ProcessVideoFormat.duration(record.durationMs), width: 130),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            Padding(
              padding: EdgeInsets.only(
                top: _AiVisionVideoChoosePageState._rowTop,
                bottom: _AiVisionVideoChoosePageState._rowBottom,
                right: _AiVisionVideoChoosePageState._columnGap * scale,
              ),
              child: SizedBox(
                width: cell.width * scale,
                child: Text(
                  cell.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          Expanded(
            child: Center(
              // Do not wrap CyberButton in a shorter SizedBox — that clips glyphs.
              child: CyberButton(
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                onPressed: onSelect,
                child: Text(
                  selectLabel,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(fontSize: 20, height: 1.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
