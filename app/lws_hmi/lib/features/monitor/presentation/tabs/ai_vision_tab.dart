import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/ai/application/ai_vision_live_stream_detect_coordinator.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_session.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_timeline.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/features/monitor/presentation/ai_vision_overlay_state.dart';
import 'package:lws_hmi/features/monitor/presentation/ai_vision_selected_ui_mode.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_chrome.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_video/application/video_cover_extractor.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/features/process_video/infrastructure/sqlite_process_video_repository.dart';
import 'package:lws_hmi/features/process_video/presentation/process_video_format.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_scope.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_snapshot_store.dart';
import 'package:video_player/video_player.dart';

/// lws-ui `fragment_ai_vision` — Work Info + Choose; preview-stack actions.
class AiVisionTab extends StatefulWidget {
  const AiVisionTab({
    super.key,
    this.repository,
    this.visible = true,
    this.liveRtspUrl = 'rtsp://127.0.0.1:8554/camera/pr0',
  });

  final ProcessVideoRepository? repository;
  final bool visible;
  final String liveRtspUrl;

  static const labelBar = Color(0xCC2E3653);

  @override
  State<AiVisionTab> createState() => _AiVisionTabState();
}

class _AiVisionTabState extends State<AiVisionTab> {
  static const _overlayTickMs = 250;

  late final ProcessVideoRepository _repo =
      widget.repository ?? SqliteProcessVideoRepository();
  AiVisionLiveStreamDetectCoordinator? _liveDetect;
  ProcessVideoRecord? _selected;
  ProcessVideoAiSession? _session;
  VideoPlayerController? _playback;
  File? _coverFile;
  final ValueNotifier<AiVisionOverlayState> _overlay =
      ValueNotifier(AiVisionOverlayState.idle);
  AiVisionSelectedUiMode _mode = AiVisionSelectedUiMode.liveNoVideo;
  bool _showPlayPause = false;
  bool _playing = false;
  List<ProcessVideoAiTimelineFrame> _replayFrames = const [];
  Timer? _overlayTickTimer;
  Timer? _playPauseHideTimer;
  VoidCallback? _playbackListener;

  @override
  void initState() {
    super.initState();
    ProcessParametersSnapshotStore.instance.addListener(_onSnapshotChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.visible) {
        _ensureLive();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AiVisionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) {
      return;
    }
    if (widget.visible) {
      if (_selected == null) {
        _ensureLive();
      }
    } else {
      unawaited(_liveDetect?.setActive(false));
    }
  }

  @override
  void dispose() {
    _overlayTickTimer?.cancel();
    _playPauseHideTimer?.cancel();
    ProcessParametersSnapshotStore.instance.removeListener(_onSnapshotChanged);
    unawaited(_liveDetect?.setActive(false));
    AiDaemonSupervisor.instance.cameraAiPublisher.lastSample
        .removeListener(_onLiveSample);
    _detachSession();
    _disposePlayback();
    _overlay.dispose();
    if (widget.repository == null) {
      unawaited(_repo.close());
    }
    super.dispose();
  }

  void _setOverlay(AiVisionOverlayState next) {
    if (_overlay.value.sameVisual(next)) {
      return;
    }
    _overlay.value = next;
  }

  void _onSnapshotChanged() {
    if (_selected == null && mounted) {
      setState(() {});
    }
  }

  void _ensureLive() {
    if (!mounted || _selected != null || !widget.visible) {
      return;
    }
    final ai = AdvancedSettingsScope.maybeAiOf(context);
    if (ai == null) {
      return;
    }
    _liveDetect ??= AiVisionLiveStreamDetectCoordinator(aiAssistance: ai);
    unawaited(_liveDetect!.setActive(true));
    AiDaemonSupervisor.instance.cameraAiPublisher.lastSample
      ..removeListener(_onLiveSample)
      ..addListener(_onLiveSample);
  }

  void _onLiveSample() {
    if (_selected != null || !mounted) {
      return;
    }
    final sample =
        AiDaemonSupervisor.instance.cameraAiPublisher.lastSample.value;
    // lws-ui live: only draw when stain has a target; otherwise clear overlay.
    if (sample == null || !sample.success || sample.boxes.isEmpty) {
      _setOverlay(AiVisionOverlayState.idle);
      return;
    }
    _setOverlay(AiVisionOverlayState.fromSample(sample));
  }

  void _startOverlayTicks() {
    _overlayTickTimer?.cancel();
    _overlayTickTimer = Timer.periodic(
      const Duration(milliseconds: _overlayTickMs),
      (_) => _tickRecordedOverlay(),
    );
    _tickRecordedOverlay();
  }

  void _stopOverlayTicks() {
    _overlayTickTimer?.cancel();
    _overlayTickTimer = null;
  }

  /// lws-ui `updateOfflineInferenceOverlay`: sample timeline at playback position.
  void _tickRecordedOverlay() {
    if (!mounted || _mode != AiVisionSelectedUiMode.playback) {
      return;
    }
    final pos = _playback?.value.position.inMilliseconds ??
        _session?.playbackPositionMs ??
        0;
    ProcessVideoAiTimelineFrame? frame;
    final session = _session;
    if (session != null) {
      frame = session.timeline.findFrameAt(pos);
    } else if (_replayFrames.isNotEmpty) {
      frame = _replayFrames.first;
      for (final f in _replayFrames) {
        if (f.timeMs <= pos) {
          frame = f;
        } else {
          break;
        }
      }
    }
    if (frame == null) {
      // Keep STAIN_DETECT HUD while waiting for the first sample.
      if (!_overlay.value.hasHud) {
        _setOverlay(AiVisionOverlayState.stainDetectActive());
      }
      return;
    }
    _setOverlay(AiVisionOverlayState.fromSample(frame.sample));
  }

  void _detachSession() {
    final session = _session;
    _session = null;
    if (session != null) {
      session.onPlaybackEnded = null;
      session.onFinalize = null;
      session.removeTimelineListener(_onTimelineFrame);
      ProcessVideoAiSessionRegistry.instance
          .release(session, ProcessVideoAiHolder.ui);
    }
  }

  void _disposePlayback() {
    final c = _playback;
    _playback = null;
    _playing = false;
    if (c != null) {
      final listener = _playbackListener;
      if (listener != null) {
        c.removeListener(listener);
      }
      unawaited(c.dispose());
    }
    _playbackListener = null;
  }

  void _onTimelineFrame(ProcessVideoAiTimelineFrame frame) {
    // Position-driven tick owns overlay during playback.
  }

  void _onSessionPlaybackEnded(ProcessVideoAiSession session) {
    if (!mounted || !identical(session, _session)) {
      return;
    }
    // Inference clock may finish before Exo/video EOS — wait for player.
    _maybeEnterIdleAfterPlayback();
  }

  void _onSessionFinalize(ProcessVideoAiSession session) {
    if (!mounted || !identical(session, _session)) {
      return;
    }
    if (_mode == AiVisionSelectedUiMode.playback) {
      _maybeEnterIdleAfterPlayback();
    }
  }

  void _maybeEnterIdleAfterPlayback() {
    if (_mode != AiVisionSelectedUiMode.playback) {
      return;
    }
    final player = _playback;
    if (player != null && player.value.isInitialized) {
      final v = player.value;
      final nearEnd = v.duration > Duration.zero &&
          v.position >= v.duration - const Duration(milliseconds: 120);
      // Inference clock ended early — keep playing until video EOS.
      if (!nearEnd &&
          (v.isPlaying ||
              v.position + const Duration(milliseconds: 200) < v.duration)) {
        return;
      }
    }
    _enterIdleDetectionComplete();
  }

  /// lws-ui: after Detect/Replay EOS → cover + Replay/Re-detect; HUD `AI: IDLE`, boxes cleared.
  void _enterIdleDetectionComplete() {
    if (_mode != AiVisionSelectedUiMode.playback) {
      return;
    }
    _stopOverlayTicks();
    _playPauseHideTimer?.cancel();
    _detachSession();
    _disposePlayback();
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    _setOverlay(AiVisionOverlayState.selectedIdle(l10n));
    setState(() {
      _mode = AiVisionSelectedUiMode.idleDetectionComplete;
      _showPlayPause = false;
      _replayFrames = const [];
    });
  }

  Future<void> _chooseVideo() async {
    final picked = await Navigator.of(context).pushNamed(
      AppRoutes.aiVisionChoose,
    );
    if (!mounted || picked is! ProcessVideoRecord) {
      return;
    }
    await _applySelected(picked);
  }

  Future<void> _applySelected(ProcessVideoRecord record) async {
    _stopOverlayTicks();
    _detachSession();
    _disposePlayback();
    await _liveDetect?.setActive(false);
    AiDaemonSupervisor.instance.cameraAiPublisher.lastSample
        .removeListener(_onLiveSample);

    File? cover;
    try {
      cover = await VideoCoverExtractor().extractFirstFrameJpeg(
        videoPath: record.videoPath,
        videoId: record.videoId,
      );
    } catch (_) {}

    final source = File(record.videoPath);
    final cacheKey = ProcessVideoAiInferencePaths.cacheKey(record, source);
    final timelineFile =
        ProcessVideoAiInferencePaths.timelineJson(record, cacheKey);
    final hasTimeline =
        await ProcessVideoAiTimelinePersistence.hasReplayData(timelineFile);

    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _selected = record;
      _coverFile = cover;
      _replayFrames = const [];
      _showPlayPause = false;
      _mode = hasTimeline
          ? AiVisionSelectedUiMode.idleDetectionComplete
          : AiVisionSelectedUiMode.idleReadyToDetect;
    });
    _setOverlay(AiVisionOverlayState.selectedIdle(l10n));
    // First-time select: auto Detect (cover + manual Detect only if start fails).
    if (!hasTimeline) {
      await _startDetect(force: false);
    }
  }

  Future<VideoPlayerController?> _ensurePlayback() async {
    final record = _selected;
    if (record == null) {
      return null;
    }
    if (_playback != null && _playback!.value.isInitialized) {
      return _playback;
    }
    _disposePlayback();
    final file = File(record.videoPath);
    if (!await file.exists()) {
      return null;
    }
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    await controller.setLooping(false);
    void listener() {
      if (!mounted || !identical(_playback, controller)) {
        return;
      }
      final v = controller.value;
      final playing = v.isPlaying;
      if (playing != _playing) {
        setState(() => _playing = playing);
      }
      final nearEnd = v.duration > Duration.zero &&
          v.position >= v.duration - const Duration(milliseconds: 80);
      if (_mode == AiVisionSelectedUiMode.playback && nearEnd) {
        _enterIdleDetectionComplete();
      }
    }

    controller.addListener(listener);
    _playbackListener = listener;
    if (!mounted) {
      await controller.dispose();
      return null;
    }
    setState(() {
      _playback = controller;
      _playing = controller.value.isPlaying;
    });
    return controller;
  }

  Future<void> _startDetect({required bool force}) async {
    final l10n = AppLocalizations.of(context)!;
    final record = _selected;
    if (record == null) {
      return;
    }
    if (!AiDaemonSupervisor.instance.isReady) {
      final ok = await AiDaemonSupervisor.instance.ensureStarted();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.aiVisionAiEngineNotReady)),
          );
        }
        return;
      }
    }

    final previous = _session;
    _session = null;
    if (previous != null) {
      previous.onPlaybackEnded = null;
      previous.onFinalize = null;
      previous.removeTimelineListener(_onTimelineFrame);
      ProcessVideoAiSessionRegistry.instance
          .release(previous, ProcessVideoAiHolder.ui);
    }

    final source = File(record.videoPath);
    final session = ProcessVideoAiSessionRegistry.instance.acquire(
      record: record,
      sourceFile: source,
      holder: ProcessVideoAiHolder.ui,
      force: force,
    );
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.aiVisionOfflineInferenceNotAvailable)),
        );
      }
      return;
    }
    _session = session;
    session.onPlaybackEnded = _onSessionPlaybackEnded;
    session.onFinalize = _onSessionFinalize;
    session.addTimelineListener(_onTimelineFrame);
    // Reused finished session: start() resets clock + timeline.
    session.start();

    final player = await _ensurePlayback();
    await player?.seekTo(Duration.zero);
    unawaited(player?.play());

    if (!mounted) {
      return;
    }
    _setOverlay(AiVisionOverlayState.stainDetectActive());
    setState(() {
      _mode = AiVisionSelectedUiMode.playback;
      _showPlayPause = false;
      _replayFrames = const [];
      _playing = player?.value.isPlaying ?? false;
    });
    _startOverlayTicks();
  }

  Future<void> _startReplay() async {
    final l10n = AppLocalizations.of(context)!;
    final record = _selected;
    if (record == null) {
      return;
    }
    final source = File(record.videoPath);
    final cacheKey = ProcessVideoAiInferencePaths.cacheKey(record, source);
    final file = ProcessVideoAiInferencePaths.timelineJson(record, cacheKey);
    var timeline = ProcessVideoAiSessionRegistry.instance
        .peekByCacheKey(cacheKey)
        ?.timeline;
    timeline ??= await ProcessVideoAiTimelinePersistence.load(file);
    final frames = timeline?.snapshotFrames() ?? const [];
    if (frames.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.aiVisionInferenceVideoNotReady)),
        );
      }
      return;
    }

    _detachSession();
    _stopOverlayTicks();
    final player = await _ensurePlayback();
    await player?.seekTo(Duration.zero);
    unawaited(player?.play());

    if (!mounted) {
      return;
    }
    _setOverlay(AiVisionOverlayState.fromSample(frames.first.sample));
    setState(() {
      _mode = AiVisionSelectedUiMode.playback;
      _replayFrames = frames;
      _showPlayPause = false;
      _playing = player?.value.isPlaying ?? false;
    });
    _startOverlayTicks();
  }

  void _togglePlayPause() {
    final player = _playback;
    final session = _session;
    if (player == null || !player.value.isInitialized) {
      return;
    }
    CyberClickSoundRegistry.playClick();
    if (player.value.isPlaying) {
      unawaited(player.pause());
      session?.pausePlaybackClock();
    } else {
      unawaited(player.play());
      session?.resumePlaybackClock();
    }
    setState(() => _showPlayPause = true);
    _playPauseHideTimer?.cancel();
    _playPauseHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showPlayPause = false);
      }
    });
  }

  void _onPreviewTap() {
    if (_mode != AiVisionSelectedUiMode.playback) {
      return;
    }
    setState(() => _showPlayPause = true);
    _playPauseHideTimer?.cancel();
    _playPauseHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showPlayPause = false);
      }
    });
  }

  (String process, String material, String time) _workInfoLabels(
    AppLocalizations l10n,
  ) {
    final selected = _selected;
    if (selected != null) {
      return (
        ProcessVideoFormat.workMode(selected.processType),
        ProcessVideoFormat.material(selected),
        ProcessVideoFormat.recordingTime(selected),
      );
    }
    final snap = ProcessParametersSnapshotStore.instance.snapshot;
    if (snap == null) {
      return (
        l10n.aiVisionWorkInfoUnavailable,
        l10n.aiVisionWorkInfoUnavailable,
        l10n.aiVisionWorkInfoUnavailable,
      );
    }
    String process = l10n.aiVisionWorkInfoUnavailable;
    final pt = snap['processType'];
    if (pt is int) {
      try {
        process = ProcessModeLabels.wheelLabel(ProcessType.fromWireValue(pt));
      } catch (_) {}
    }
    String material = l10n.aiVisionWorkInfoUnavailable;
    final name = snap['materialName']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      material = name;
    } else {
      final mt = snap['materialType'];
      if (mt is int) {
        try {
          material = MaterialType.fromStorageValue(mt).englishName;
        } catch (_) {}
      }
    }
    return (process, material, l10n.aiVisionWorkInfoUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final info = _workInfoLabels(l10n);
    final showDetect = _mode == AiVisionSelectedUiMode.idleReadyToDetect;
    final showPostEos = _mode == AiVisionSelectedUiMode.idleDetectionComplete;
    final showCover = _selected != null &&
        (_mode == AiVisionSelectedUiMode.idleReadyToDetect ||
            _mode == AiVisionSelectedUiMode.idleDetectionComplete);
    final showPlayer = _mode == AiVisionSelectedUiMode.playback &&
        _playback != null &&
        _playback!.value.isInitialized;

    return Padding(
      padding: const EdgeInsets.all(MonitorDimens.pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: MonitorDimens.aiInfoW,
            child: Column(
              children: [
                Expanded(
                  child: MonitorGlassCard(
                    padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 21),
                          child: Text(
                            l10n.deviceMonitorWorkInfoTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 35,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                        _InfoBlock(
                          label: l10n.aiVisionProcessTypeText,
                          value: info.$1,
                        ),
                        _InfoBlock(
                          label: l10n.aiVisionMaterialTypeText,
                          value: info.$2,
                        ),
                        _InfoBlock(
                          label: l10n.processVideoRecordingTime,
                          value: info.$3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CyberButton(
                    variant: CyberButtonVariant.primary,
                    shape: CyberButtonShape.rounded,
                    stretch: true,
                    height: 56,
                    borderGradientCenter:
                        CyberBorderGradientCenter.topLeftBottomRight,
                    onPressed: () => unawaited(_chooseVideo()),
                    child: Text(
                      l10n.aiVisionChooseBtn,
                      softWrap: false,
                      style: const TextStyle(fontSize: 24, height: 1.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: MonitorGlassCard(
              padding: const EdgeInsets.all(10),
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onPreviewTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_selected == null)
                        IpCameraPreview(
                          rtspUrl: Uri.parse(widget.liveRtspUrl),
                          linkPhase: IpCameraUiPhase.connected,
                          relayReady: true,
                        )
                      else if (showPlayer)
                        // Keep video out of overlay rebuilds (ValueListenableBuilder below).
                        RepaintBoundary(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _playback!.value.size.width,
                              height: _playback!.value.size.height,
                              child: VideoPlayer(_playback!),
                            ),
                          ),
                        )
                      else if (showCover &&
                          _coverFile != null &&
                          _coverFile!.existsSync())
                        Image.file(_coverFile!, fit: BoxFit.contain)
                      else
                        Center(
                          child: Text(
                            l10n.aiVisionSelectVideoFirst,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ValueListenableBuilder<AiVisionOverlayState>(
                        valueListenable: _overlay,
                        builder: (context, overlay, _) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (overlay.hasBoxes)
                                CustomPaint(
                                  painter: _AiBoxesPainter(
                                    overlay: overlay,
                                    videoSize:
                                        _playback?.value.isInitialized == true
                                            ? _playback!.value.size
                                            : null,
                                  ),
                                ),
                              if (overlay.hasHud)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: _AiHudCard(
                                    overlay: overlay,
                                    l10n: l10n,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (showDetect)
                        Center(
                          child: _PreviewActionButton(
                            label: l10n.aiVisionDetectBtn,
                            variant: CyberButtonVariant.primary,
                            onPressed: () =>
                                unawaited(_startDetect(force: false)),
                          ),
                        ),
                      if (showPostEos)
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PreviewActionButton(
                                label: l10n.aiVisionVideoReplay,
                                variant: CyberButtonVariant.light,
                                onPressed: () => unawaited(_startReplay()),
                              ),
                              const SizedBox(width: 24),
                              _PreviewActionButton(
                                label: l10n.aiVisionReinferBtn,
                                variant: CyberButtonVariant.light,
                                onPressed: () =>
                                    unawaited(_startDetect(force: true)),
                              ),
                            ],
                          ),
                        ),
                      if (_mode == AiVisionSelectedUiMode.playback &&
                          _showPlayPause)
                        Center(
                          child: Material(
                            color: const Color(0x99000000),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _togglePlayPause,
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: Icon(
                                  _playing ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.label,
    required this.onPressed,
    this.variant = CyberButtonVariant.primary,
  });

  final String label;
  final VoidCallback onPressed;
  final CyberButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    // Do not wrap CyberButton in a shorter SizedBox — that clips glyphs.
    // Extra child Padding + oversized Text also fights CyberButton's own pad.
    return CyberButton(
      variant: variant,
      shape: CyberButtonShape.rounded,
      borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
      clickSoundEnabled: true,
      onPressed: onPressed,
      child: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontSize: 24, height: 1.0),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AiVisionTab.labelBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 31, vertical: 16),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE1E1E1),
                  fontSize: 24,
                  height: 1.0,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(31, 16, 31, 0),
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE1E1E1),
                fontSize: 24,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiHudCard extends StatelessWidget {
  const _AiHudCard({required this.overlay, required this.l10n});

  final AiVisionOverlayState overlay;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final status = overlay.hudStatus?.trim();
    final detail = overlay.hudDetail?.trim();
    final statusLine = (status == null || status.isEmpty)
        ? null
        : l10n.aiOverlayHudStatusPrefix(status);
    final detailLine = (detail == null || detail.isEmpty) ? null : detail;
    if (statusLine == null && detailLine == null) {
      return const SizedBox.shrink();
    }
    return MonitorGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderGradientCenter: CyberBorderGradientCenter.topLeftBottomRight,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (statusLine != null) Text(statusLine),
            if (statusLine != null && detailLine != null)
              const SizedBox(height: 4),
            if (detailLine != null) Text(detailLine),
          ],
        ),
      ),
    );
  }
}

/// lws-ui [DetectionOverlayView]: pixel boxes → normalized → fit-center content.
class _AiBoxesPainter extends CustomPainter {
  _AiBoxesPainter({required this.overlay, this.videoSize});

  final AiVisionOverlayState overlay;
  final Size? videoSize;

  static const _boxColor = Color(0xFF00E676);

  @override
  void paint(Canvas canvas, Size size) {
    final iw = videoSize != null && videoSize!.width > 0
        ? videoSize!.width
        : (overlay.imageWidth > 0 ? overlay.imageWidth.toDouble() : size.width);
    final ih = videoSize != null && videoSize!.height > 0
        ? videoSize!.height
        : (overlay.imageHeight > 0
            ? overlay.imageHeight.toDouble()
            : size.height);
    final scale = math.min(size.width / iw, size.height / ih);
    final contentW = iw * scale;
    final contentH = ih * scale;
    final contentLeft = (size.width - contentW) / 2;
    final contentTop = (size.height - contentH) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _boxColor;
    final labelStyle = TextPainter(
      textDirection: TextDirection.ltr,
    );
    final labelBg = Paint()..color = const Color(0x992B2B2B);
    final srcW =
        overlay.imageWidth > 0 ? overlay.imageWidth.toDouble() : iw;
    final srcH =
        overlay.imageHeight > 0 ? overlay.imageHeight.toDouble() : ih;
    for (final box in overlay.boxes) {
      var x1 = (box['x1'] as num?)?.toDouble() ?? 0;
      var y1 = (box['y1'] as num?)?.toDouble() ?? 0;
      var x2 = (box['x2'] as num?)?.toDouble() ?? 0;
      var y2 = (box['y2'] as num?)?.toDouble() ?? 0;
      // Pixel → normalized (lws-ui DetectionOverlayMapper.fromOpencvStainDetect).
      if (x2 > 1.5 || y2 > 1.5) {
        x1 /= srcW;
        y1 /= srcH;
        x2 /= srcW;
        y2 /= srcH;
      }
      final rect = Rect.fromLTRB(
        contentLeft + x1 * contentW,
        contentTop + y1 * contentH,
        contentLeft + x2 * contentW,
        contentTop + y2 * contentH,
      );
      if (rect.width < 2 || rect.height < 2) {
        continue;
      }
      canvas.drawRect(rect, paint);
      final label = box['label']?.toString().trim() ?? '';
      if (label.isEmpty) {
        continue;
      }
      labelStyle.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      );
      labelStyle.layout();
      final padH = labelStyle.height * 0.35;
      final padV = labelStyle.height * 0.2;
      final textH = labelStyle.height + padV * 2;
      final bgTop = math.max(0.0, rect.top - textH - padV);
      final bgRect = Rect.fromLTWH(
        rect.left,
        bgTop,
        labelStyle.width + padH * 2,
        textH,
      );
      canvas.drawRect(bgRect, labelBg);
      labelStyle.paint(
        canvas,
        Offset(rect.left + padH, bgTop + textH - padV - labelStyle.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AiBoxesPainter oldDelegate) =>
      oldDelegate.overlay != overlay || oldDelegate.videoSize != videoSize;
}
