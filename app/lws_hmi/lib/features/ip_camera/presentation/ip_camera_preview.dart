import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/mpp_video_route_gate.dart';
import 'package:video_player/video_player.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';

abstract interface class IpCameraPreviewPlayer implements Listenable {
  Future<void> initialize();

  Future<void> play();

  Future<void> dispose();

  bool get isInitialized;

  double get aspectRatio;

  String? get errorDescription;

  Widget buildVideo();
}

typedef IpCameraPreviewPlayerFactory = IpCameraPreviewPlayer Function(Uri url);

IpCameraPreviewPlayer createIpCameraPreviewPlayer(Uri url) {
  return _VideoPlayerPreviewPlayer(
    VideoPlayerController.networkUrl(
      url,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    ),
  );
}

final class _VideoPlayerPreviewPlayer implements IpCameraPreviewPlayer {
  _VideoPlayerPreviewPlayer(this._controller);

  final VideoPlayerController _controller;

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setVolume(0);
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  double get aspectRatio => _controller.value.aspectRatio;

  @override
  String? get errorDescription => _controller.value.errorDescription;

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  Widget buildVideo() => VideoPlayer(_controller);
}

/// RTSP preview surface backed by the Linux GStreamer video texture.
class IpCameraPreview extends StatefulWidget {
  const IpCameraPreview({
    super.key,
    required this.rtspUrl,
    required this.linkPhase,
    /// True when [rtspUrl] may be opened (camera link up).
    this.relayReady = true,
    this.playerFactory = createIpCameraPreviewPlayer,
  });

  final Uri? rtspUrl;
  final IpCameraUiPhase linkPhase;
  final bool relayReady;
  final IpCameraPreviewPlayerFactory playerFactory;

  @override
  State<IpCameraPreview> createState() => _IpCameraPreviewState();
}

class _IpCameraPreviewState extends State<IpCameraPreview> {
  IpCameraPreviewPlayer? _player;
  Uri? _activeUrl;
  Object? _playerError;
  bool _starting = false;
  int _generation = 0;
  bool get _canPreview =>
      widget.linkPhase == IpCameraUiPhase.connected &&
      widget.relayReady &&
      widget.rtspUrl != null;

  @override
  void initState() {
    super.initState();
    _syncPlayer();
  }

  @override
  void didUpdateWidget(covariant IpCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rtspUrl != widget.rtspUrl ||
        oldWidget.linkPhase != widget.linkPhase ||
        oldWidget.relayReady != widget.relayReady ||
        oldWidget.playerFactory != widget.playerFactory) {
      _syncPlayer();
    }
  }

  void _syncPlayer() {
    final url = _canPreview ? widget.rtspUrl : null;
    if (url == null) {
      unawaited(_replacePlayer(null));
      return;
    }
    if (_activeUrl == url && (_player != null || _starting)) {
      return;
    }
    unawaited(_replacePlayer(url));
  }

  Future<void> _replacePlayer(Uri? url) async {
    final generation = ++_generation;
    final previous = _player;
    previous?.removeListener(_onPlayerChanged);
    _player = null;
    _activeUrl = url;
    _playerError = null;
    _starting = url != null;
    if (mounted) {
      setState(() {});
    }
    if (previous != null) {
      // Register with the route gate so VOD/pages wait for MPP teardown.
      final released = previous.dispose().catchError((Object _) {});
      MppVideoRouteGate.scheduleRelease(() async {
        await released;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await released;
    }

    if (url == null || generation != _generation || !mounted) {
      return;
    }

    await MppVideoRouteGate.beforeAcquire();
    if (generation != _generation || !mounted) {
      return;
    }

    IpCameraPreviewPlayer? next;
    try {
      next = widget.playerFactory(url);
      next.addListener(_onPlayerChanged);
      _player = next;
      await next.initialize().timeout(const Duration(seconds: 8));
      if (generation != _generation || !mounted) {
        return;
      }
      await next.play();
      if (generation != _generation || !mounted) {
        return;
      }
      setState(() => _starting = false);
    } catch (error) {
      if (generation == _generation && mounted) {
        next?.removeListener(_onPlayerChanged);
        _player = null;
        await next?.dispose();
        if (generation == _generation && mounted) {
          setState(() {
            _playerError = error;
            _starting = false;
          });
        }
      }
    }
  }

  void _onPlayerChanged() {
    final player = _player;
    if (!mounted || player == null) {
      return;
    }
    final error = player.errorDescription;
    if (error != null) {
      setState(() {
        _playerError = error;
        _starting = false;
      });
    } else if (player.isInitialized) {
      setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    final player = _player;
    _player = null;
    player?.removeListener(_onPlayerChanged);
    if (player != null) {
      final released = player.dispose().catchError((Object _) {});
      MppVideoRouteGate.scheduleRelease(() async {
        await released;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.linkPhase == IpCameraUiPhase.failed) {
      return _Placeholder(
        icon: Icons.videocam_off,
        label: l10n.deviceControlCameraUnavailable,
        color: const Color(0xFFE53935),
      );
    }
    if (!_canPreview) {
      return _Placeholder(
        icon: Icons.hourglass_top,
        label: l10n.ipCameraEstablishingVideo,
        showSpinner: true,
      );
    }

    final error = _playerError;
    if (error != null) {
      return _Placeholder(
        icon: Icons.videocam_off,
        label: '${l10n.ipCameraPreviewFailed}\n$error',
        color: const Color(0xFFE53935),
        action: TextButton(
          onPressed: () => unawaited(_replacePlayer(widget.rtspUrl)),
          child: Text(l10n.retryText),
        ),
      );
    }

    final player = _player;
    if (_starting || player == null || !player.isInitialized) {
      return _Placeholder(
        icon: Icons.hourglass_top,
        label: l10n.ipCameraEstablishingVideo,
        showSpinner: true,
      );
    }

    final aspectRatio = player.aspectRatio > 0 ? player.aspectRatio : 16 / 9;
    return Center(
      key: const Key('ip-camera-live-preview'),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: player.buildVideo(),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.label,
    this.color = Colors.white70,
    this.showSpinner = false,
    this.action,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool showSpinner;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(icon, size: 48, color: color),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.hmiTypography.caption.copyWith(color: color),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      ),
    );
  }
}
