import 'dart:async';
import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/features/monitor/presentation/tabs/videos_tab.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/application/video_cover_extractor.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_dialogs.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/call_back_home_button.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/mpp_video_route_gate.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/hmi/word_boundary_label.dart';
import 'package:video_player/video_player.dart';

/// lws-ui `ProcessVideoDetailsActivity` — left params + right fixed player.
///
/// Own route (separate from Monitor / AI Vision). Acquires MPP only after
/// [MppVideoRouteGate.beforeAcquire]; releases on pop / dispose so the previous
/// page's decoder is never concurrent.
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
  /// Page padding — lws-ui `frost_dialog_content_padding`.
  static const _pagePad = 24.0;

  /// Right player column — lws-ui fixed `716dp` (scaled to viewport).
  static const _playerDesignWidth = 716.0;

  late final ProcessVideoRepository _repo =
      widget.args.repository ?? SqliteProcessVideoRepository();
  ProcessVideoRecord? _record;
  VideoPlayerController? _player;
  File? _poster;
  String? _error;
  bool _loading = true;

  /// eLinux GStreamer often stays black until the first play; keep JPEG poster
  /// until the operator starts playback.
  bool _playbackStarted = false;
  bool _releasing = false;

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
        // Cover (MPP JPEG helper via runExclusive) then decoder lease — never
        // overlap with background cover drain or a prior route's VOD/RTSP.
        await _loadPoster(row);
        if (!mounted) {
          return;
        }
        await MppVideoRouteGate.beforeAcquire();
        if (!mounted) {
          return;
        }
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

  Future<void> _loadPoster(ProcessVideoRecord row) async {
    try {
      final cover = await VideoCoverExtractor().extractFirstFrameJpeg(
        videoPath: row.videoPath,
        videoId: row.videoId,
      );
      if (!mounted || cover == null || !cover.existsSync()) {
        return;
      }
      setState(() => _poster = cover);
    } catch (_) {}
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
      // No seekTo(0) after init — eLinux qtdemux has errored under MPP load.
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

  void _onPlaybackStarted() {
    if (_playbackStarted || !mounted) {
      return;
    }
    setState(() => _playbackStarted = true);
  }

  Future<void> _releasePlayer() async {
    final player = _player;
    if (player == null) {
      return;
    }
    _player = null;
    if (mounted) {
      setState(() {});
    }
    try {
      await player.pause();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  Future<void> _handleBack({Object? result}) async {
    if (_releasing) {
      return;
    }
    _releasing = true;
    final release = _releasePlayer();
    MppVideoRouteGate.scheduleRelease(() => release);
    try {
      await release;
    } finally {
      _releasing = false;
    }
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _delete() async {
    final record = _record;
    if (record?.id == null) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    final ok = await showProcessVideoDeleteDialog(context: context);
    if (ok != true) {
      return;
    }
    await _repo.deleteById(record!.id!);
    if (mounted) {
      await _handleBack(result: true);
    }
  }

  Future<void> _upload() async {
    if (_record?.id == null) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    // UI only — cloud upload pipeline lands later.
    await showProcessVideoUploadDialog(context: context);
  }

  @override
  void dispose() {
    final player = _player;
    _player = null;
    if (player != null) {
      MppVideoRouteGate.scheduleRelease(() async {
        try {
          await player.pause();
        } catch (_) {}
        try {
          await player.dispose();
        } catch (_) {}
      });
    }
    if (widget.args.repository == null) {
      unawaited(_repo.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final record = _record;

    return PopScope(
      canPop: _player == null && !_releasing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleBack());
      },
      child: SettingsBlurredPageShell(
        // Same stack as Monitor / AI Vision choose: home wallpaper → σ30 plate.
        blurSigma: SettingsPerspectiveChrome.blurSigma,
        backdropBuilder: () => const Stack(
          fit: StackFit.expand,
          children: [
            SettingsHomeBackdrop(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x16000000), Color(0x26000000)],
                ),
              ),
            ),
          ],
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : record == null
                  ? Center(
                      child: Text(
                        l10n.processVideoPlaybackFailed,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final scale =
                            (constraints.maxWidth / 1280).clamp(0.55, 1.0);
                        final minParams = 360.0 * scale;
                        final gap = _pagePad * scale;
                        var playerWidth = _playerDesignWidth * scale;
                        final maxPlayer =
                            constraints.maxWidth - gap - minParams;
                        if (playerWidth > maxPlayer) {
                          playerWidth = maxPlayer.clamp(200.0, playerWidth);
                        }
                        return Padding(
                          padding: const EdgeInsets.all(_pagePad),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _ParameterColumn(
                                  record: record,
                                  title: l10n.processVideoParametersTitle,
                                  backLabel: l10n.equipmentStatusBack,
                                  uploadLabel: l10n.uploadText,
                                  deleteLabel: l10n.deleteText,
                                  labelWidth: 230 * scale,
                                  onBack: () => unawaited(_handleBack()),
                                  onUpload: () => unawaited(_upload()),
                                  onDelete: () => unawaited(_delete()),
                                ),
                              ),
                              SizedBox(width: gap),
                              SizedBox(
                                width: playerWidth,
                                child: _PlayerPane(
                                  player: _player,
                                  poster: _poster,
                                  showPoster: !_playbackStarted,
                                  error: _error,
                                  failedLabel: l10n.processVideoPlaybackFailed,
                                  onPlaybackStarted: _onPlaybackStarted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

/// Left column: Back chrome + Frost param card + Upload / Delete.
final class _ParameterColumn extends StatelessWidget {
  const _ParameterColumn({
    required this.record,
    required this.title,
    required this.backLabel,
    required this.uploadLabel,
    required this.deleteLabel,
    required this.labelWidth,
    required this.onBack,
    required this.onUpload,
    required this.onDelete,
  });

  /// Outer inset and Upload↔Delete gap share one value so side margins match.
  static const double _parameterActionGap = 16;

  final ProcessVideoRecord record;
  final String title;
  final String backLabel;
  final String uploadLabel;
  final String deleteLabel;
  final double labelWidth;
  final VoidCallback onBack;
  final VoidCallback onUpload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: WorkModeStatusBarDimens.height,
            // Settings / Monitor nested chrome: full title, no orange edges.
            child: CallBackHomeButton(
              accent: WorkModeAccent.weld,
              label: backLabel,
              onPressed: onBack,
              expandWidth: false,
              showEdgeAccent: false,
              useHomeIcon: false,
            ),
          ),
        ),
        const SizedBox(height: 19),
        Expanded(
          child: CyberOutlinedPanel(
            outline: const CyberPanelOutline(
              style: CyberPanelOutlineStyle.uniform,
              width: 1.0,
              cornerRadius: CyberDimens.cornerRadius,
              uniformColor: CyberColors.borderUniform,
            ),
            color: Colors.white.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      title,
                      style: context.hmiTypography.navigation.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 21),
                  Expanded(
                    child: _ParameterList(
                      record: record,
                      labelWidth: labelWidth,
                    ),
                  ),
                  // Side insets == inter-button gap so Upload/Delete fill
                  // the frosted panel with equal outer/inner spacing.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _parameterActionGap,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: HmiButton(
                            label: uploadLabel,
                            size: HmiButtonSize.medium,
                            widthPolicy: HmiButtonWidthPolicy.fill,
                            variant: CyberButtonVariant.primary,
                            shape: CyberButtonShape.rounded,
                            onPressed: onUpload,
                          ),
                        ),
                        const SizedBox(width: _parameterActionGap),
                        Expanded(
                          child: HmiButton(
                            label: deleteLabel,
                            size: HmiButtonSize.medium,
                            widthPolicy: HmiButtonWidthPolicy.fill,
                            variant: CyberButtonVariant.secondary,
                            shape: CyberButtonShape.rounded,
                            borderGradientCenter:
                                CyberBorderGradientCenter.topLeftBottomRight,
                            onPressed: onDelete,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ParameterList extends StatelessWidget {
  const _ParameterList({
    required this.record,
    required this.labelWidth,
  });

  final ProcessVideoRecord record;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows(context);
    final dataStyle = context.hmiTypography.sectionTitle.copyWith(
      color: const Color(0xFFE1E1E1),
      height: 1.15,
    );
    return ListView.builder(
      padding: const EdgeInsets.only(right: 10, bottom: 16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final unit = row.unit;
        return Padding(
          padding: const EdgeInsets.fromLTRB(23, 16, 0, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  '${row.label}:',
                  style: dataStyle,
                ),
              ),
              Expanded(
                child: unit != null && unit.isNotEmpty
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: WordBoundaryLabel(
                              text: row.value,
                              style: dataStyle,
                              maxLines: 2,
                            ),
                          ),
                          Text(
                            ' $unit',
                            style: dataStyle.copyWith(
                              color: const Color(0xFFE1E1E1),
                            ),
                          ),
                        ],
                      )
                    : WordBoundaryLabel(
                        text: row.value,
                        style: dataStyle,
                        maxLines: 2,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<({String label, String value, String? unit})> _buildRows(
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final snap = record.snapshot;
    final unitStore = CommonSettingsScope.maybeOf(context);
    final unitWire = unitStore?.unitWire;
    final isMetric = LengthUnitConvert.isMetric(unitWire);
    final rows = <({String label, String value, String? unit})>[
      (
        label: l10n.processVideoWorkMode,
        value: ProcessVideoFormat.workMode(record.processType, l10n),
        unit: null,
      ),
      (
        label: l10n.processVideoMaterial,
        value: ProcessVideoFormat.material(record, l10n),
        unit: null,
      ),
    ];
    if (snap?.thickness != null) {
      final raw = snap!.thickness!;
      final display = isMetric ? raw : raw / LengthUnitConvert.mmPerInch;
      rows.add((
        label: l10n.thicknessLabel,
        value: ProcessVideoFormat.parameterValue(display),
        unit: LengthUnitConvert.suffix(unitWire),
      ));
    }
    if (snap?.gear != null) {
      rows.add((label: l10n.gearLabel, value: '${snap!.gear}', unit: null));
    }
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
        label: ProcessVideoFormat.parameterLabelPlain(entry.key, l10n),
        value: ProcessVideoFormat.parameterValue(displayValue),
        unit: ProcessVideoFormat.parameterUnit(
          entry.key,
          activeUnitWire: unitWire,
        ),
      ));
    }
    return rows;
  }

  static bool _visibleFor(ProcessType type, String key) {
    if (type == ProcessType.cncCutting && key.startsWith('process.')) {
      return true;
    }
    return ProcessParameterCatalog.byKey.containsKey(key);
  }
}

/// Right player card — fixed-width Frost panel with tap-to-show transport.
final class _PlayerPane extends StatefulWidget {
  const _PlayerPane({
    required this.player,
    required this.poster,
    required this.showPoster,
    required this.error,
    required this.failedLabel,
    required this.onPlaybackStarted,
  });

  final VideoPlayerController? player;
  final File? poster;
  final bool showPoster;
  final String? error;
  final String failedLabel;
  final VoidCallback onPlaybackStarted;

  @override
  State<_PlayerPane> createState() => _PlayerPaneState();
}

final class _PlayerPaneState extends State<_PlayerPane> {
  bool _controlsVisible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _hideTimer?.cancel();
    if (_controlsVisible) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _controlsVisible = false);
        }
      });
    }
  }

  void _bumpHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CyberOutlinedPanel(
      outline: const CyberPanelOutline(
        style: CyberPanelOutlineStyle.uniform,
        width: 1.0,
        cornerRadius: CyberDimens.cornerRadius,
        uniformColor: CyberColors.borderUniform,
      ),
      color: Colors.white.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final controller = widget.player;
    final hasPoster =
        widget.poster != null && widget.poster!.existsSync();
    if ((controller == null || !controller.value.isInitialized) &&
        !hasPoster) {
      return Center(
        child: Text(
          widget.error == null ? '…' : widget.failedLabel,
          style: context.hmiTypography.supporting.copyWith(color: Colors.white54),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Image.file(
            widget.poster!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Keep VideoPlayer mounted under the cover so eLinux
                        // can attach the texture before the first play().
                        VideoPlayer(controller),
                        if (widget.showPoster)
                          const ColoredBox(color: Colors.black),
                        if (widget.showPoster && hasPoster)
                          IgnorePointer(
                            child: Image.file(
                              widget.poster!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_controlsVisible) ...[
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TransportButton(
                        size: CyberDimens.actionButtonMediumHeight,
                        icon: Icons.replay_5,
                        iconSize: 24,
                        onPressed: () {
                          CyberClickSoundRegistry.playClick();
                          _bumpHideTimer();
                          final pos =
                              value.position - const Duration(seconds: 5);
                          unawaited(controller.seekTo(
                            pos < Duration.zero ? Duration.zero : pos,
                          ));
                        },
                      ),
                      const SizedBox(width: 32),
                      _TransportButton(
                        size: 88,
                        icon: value.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        iconSize: 42,
                        onPressed: () {
                          CyberClickSoundRegistry.playClick();
                          _bumpHideTimer();
                          if (value.isPlaying) {
                            unawaited(controller.pause());
                          } else {
                            final restartFromStart = widget.showPoster &&
                                value.position > Duration.zero;
                            widget.onPlaybackStarted();
                            unawaited(() async {
                              if (restartFromStart) {
                                await controller.seekTo(Duration.zero);
                              }
                              await controller.play();
                            }());
                          }
                        },
                      ),
                      const SizedBox(width: 32),
                      _TransportButton(
                        size: CyberDimens.actionButtonMediumHeight,
                        icon: Icons.forward_5,
                        iconSize: 24,
                        onPressed: () {
                          CyberClickSoundRegistry.playClick();
                          _bumpHideTimer();
                          final pos =
                              value.position + const Duration(seconds: 5);
                          final end = value.duration;
                          widget.onPlaybackStarted();
                          unawaited(
                            controller.seekTo(pos > end ? end : pos),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: const Color(0xCC000000),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: EdgeInsets.zero,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white70,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

final class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: const Color(0x66FFFFFF),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
