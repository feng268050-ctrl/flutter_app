import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:video_player/video_player.dart';

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
    await previous?.dispose();

    if (url == null || generation != _generation || !mounted) {
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
    player?.removeListener(_onPlayerChanged);
    unawaited(player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.linkPhase == IpCameraUiPhase.failed) {
      return const _Placeholder(
        icon: Icons.videocam_off,
        label: 'Camera unavailable',
        color: Color(0xFFE53935),
      );
    }
    if (!_canPreview) {
      return const _Placeholder(
        icon: Icons.hourglass_top,
        label: 'Establishing video…',
        showSpinner: true,
      );
    }

    final error = _playerError;
    if (error != null) {
      return _Placeholder(
        icon: Icons.videocam_off,
        label: 'Preview failed\n$error',
        color: const Color(0xFFE53935),
        action: TextButton(
          onPressed: () => unawaited(_replacePlayer(widget.rtspUrl)),
          child: const Text('Retry'),
        ),
      );
    }

    final player = _player;
    if (_starting || player == null || !player.isInitialized) {
      return const _Placeholder(
        icon: Icons.hourglass_top,
        label: 'Establishing video…',
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
              style: TextStyle(color: color, fontSize: 14),
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
