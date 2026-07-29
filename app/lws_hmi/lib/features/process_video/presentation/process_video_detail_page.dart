import 'dart:async';
import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

/// lws-ui `ProcessVideoDetailsActivity` — local playback + parameter panel.
final class ProcessVideoDetailPage extends StatefulWidget {
  const ProcessVideoDetailPage({
    super.key,
    required this.args,
  });

  final ProcessVideoDetailArgs args;

  @override
  State<ProcessVideoDetailPage> createState() => _ProcessVideoDetailPageState();
}

final class _ProcessVideoDetailPageState extends State<ProcessVideoDetailPage> {
  late final ProcessVideoRepository _repo =
      widget.args.repository ?? SqliteProcessVideoRepository();
  ProcessVideoRecord? _record;
  VideoPlayerController? _player;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _repo.open();
      final row = await _repo.getById(widget.args.recordId);
      if (!mounted) {
        return;
      }
      if (row == null) {
        setState(() {
          _error = 'missing';
          _loading = false;
        });
        return;
      }
      final missing = !await File(row.videoPath).exists();
      if (!mounted) {
        return;
      }
      setState(() {
        _record = row;
        _loading = false;
        if (missing) {
          _error = 'missing_file';
        }
      });
      if (!missing) {
        await _initPlayer(row.videoPath);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _initPlayer(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        setState(() => _error = 'missing_file');
      }
      return;
    }
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _player = controller;
        _error = null;
      });
    } catch (e) {
      await controller.dispose();
      if (mounted) {
        setState(() => _error = 'playback');
      }
    }
  }

  Future<void> _delete() async {
    final record = _record;
    if (record?.id == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    CyberClickSoundRegistry.playClick();
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
    if (ok != true) {
      return;
    }
    await _repo.deleteById(record!.id!);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    unawaited(_player?.dispose() ?? Future<void>.value());
    if (widget.args.repository == null) {
      unawaited(_repo.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final record = _record;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: ProductPageStatusBar(
        title: l10n.processVideoDetailTitle,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        onBack: () => Navigator.of(context).maybePop(),
        actions: [
          if (record != null)
            TextButton(
              onPressed: () => unawaited(_delete()),
              child: Text(l10n.deleteText),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : record == null
              ? Center(
                  child: Text(
                    l10n.processVideoPlaybackFailed,
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PlayerPane(
                        player: _player,
                        error: _error,
                        failedLabel: l10n.processVideoPlaybackFailed,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _ParameterPane(
                        record: record,
                        title: l10n.processVideoParametersTitle,
                      ),
                    ),
                  ],
                ),
    );
  }
}

final class _PlayerPane extends StatelessWidget {
  const _PlayerPane({
    required this.player,
    required this.error,
    required this.failedLabel,
  });

  final VideoPlayerController? player;
  final String? error;
  final String failedLabel;

  @override
  Widget build(BuildContext context) {
    final controller = player;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Text(
          error == null ? '…' : failedLabel,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      CyberClickSoundRegistry.playClick();
                      final pos =
                          value.position - const Duration(seconds: 5);
                      unawaited(controller.seekTo(
                        pos < Duration.zero ? Duration.zero : pos,
                      ));
                    },
                    icon: const Icon(Icons.replay_5, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {
                      CyberClickSoundRegistry.playClick();
                      if (value.isPlaying) {
                        unawaited(controller.pause());
                      } else {
                        unawaited(controller.play());
                      }
                    },
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      CyberClickSoundRegistry.playClick();
                      final pos =
                          value.position + const Duration(seconds: 5);
                      final end = value.duration;
                      unawaited(controller.seekTo(pos > end ? end : pos));
                    },
                    icon: const Icon(Icons.forward_5, color: Colors.white),
                  ),
                ],
              ),
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white70,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _ParameterPane extends StatelessWidget {
  const _ParameterPane({
    required this.record,
    required this.title,
  });

  final ProcessVideoRecord record;
  final String title;

  @override
  Widget build(BuildContext context) {
    final snap = record.snapshot;
    final unitStore = CommonSettingsScope.maybeOf(context);
    final unitWire = unitStore?.unit;
    final isMetric = LengthUnitConvert.isMetric(unitWire);
    final rows = <(String, String)>[
      ('Mode', ProcessVideoFormat.workMode(record.processType)),
      ('Material', ProcessVideoFormat.material(record)),
      if (snap?.thickness != null)
        (
          'Thickness (${LengthUnitConvert.suffix(unitWire)})',
          ProcessVideoFormat.parameterValue(
            isMetric ? snap!.thickness! : snap!.thickness! / LengthUnitConvert.mmPerInch,
          ),
        ),
      if (snap?.gear != null) ('Gear', '${snap!.gear}'),
    ];
    final params = snap?.parameters.values ?? const <String, double>{};
    for (final entry in params.entries) {
      if (!_visibleFor(record.processType, entry.key)) {
        continue;
      }
      final spec = ProcessParameterCatalog.byKey[entry.key];
      double displayValue = entry.value;
      if (!isMetric && spec != null) {
        if (spec.unit == 'mm' || spec.unit == 'mm/s') {
          displayValue = entry.value / LengthUnitConvert.mmPerInch;
        }
      }
      rows.add((
        ProcessVideoFormat.parameterLabel(
          entry.key,
          activeUnitWire: unitWire,
        ),
        ProcessVideoFormat.parameterValue(displayValue),
      ));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x332E3653),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final (label, value) = rows[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static bool _visibleFor(ProcessType type, String key) {
    // Show catalog keys that exist; hide empty-noise for CNC with no params.
    if (type == ProcessType.cncCutting && key.startsWith('process.')) {
      return true;
    }
    return ProcessParameterCatalog.byKey.containsKey(key);
  }
}
