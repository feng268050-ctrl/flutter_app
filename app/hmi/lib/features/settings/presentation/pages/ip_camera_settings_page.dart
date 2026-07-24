import 'dart:async';

import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Common Settings → Input → IP Camera: status + live RTSP preview + demo record.
class IpCameraSettingsPage extends StatefulWidget {
  const IpCameraSettingsPage({
    super.key,
    required this.services,
    this.recordingPaths = const IpCameraDemoRecordingPaths(),
    this.previewPlayerFactory = createIpCameraPreviewPlayer,
  });

  final AppServices services;
  final IpCameraDemoRecordingPaths recordingPaths;

  /// Injected in widget tests to avoid real `video_player` RTSP init hangs.
  final IpCameraPreviewPlayerFactory previewPlayerFactory;

  @override
  State<IpCameraSettingsPage> createState() => _IpCameraSettingsPageState();
}

class _IpCameraSettingsPageState extends State<IpCameraSettingsPage> {
  IpCameraProductSession? _session;
  StreamSubscription<IpCameraUiStatus>? _sub;
  StreamSubscription<IpCameraRecordingStatus>? _recSub;
  IpCameraUiStatus _status = IpCameraUiStatus.connecting;
  IpCameraRecordingStatus _recording = IpCameraRecordingStatus(
    phase: IpCameraRecordingPhase.idle,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
  String? _error;
  String? _lastSavedPath;
  bool _recordBusy = false;
  /// Avoid starting GStreamer during the push route transition (blocks UI).
  bool _routeSettled = false;
  Timer? _routeSettleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeSettleTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _routeSettled = true);
        }
      });
    });
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      final session = await widget.services.ensureIpCamera();
      if (!mounted) {
        return;
      }
      // Paint the page immediately; path bring-up continues in the background.
      setState(() {
        _session = session;
        _status = session.currentStatus;
        _recording = session.camera.recording.currentStatus;
      });
      await _sub?.cancel();
      _sub = session.status.listen((s) {
        if (mounted) {
          setState(() => _status = s);
        }
      });
      await _recSub?.cancel();
      _recSub = session.camera.recording.status.listen((s) {
        if (mounted) {
          setState(() => _recording = s);
        }
      });
      await session.start();
      await session.ensureReady();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = session.currentStatus;
        _recording = session.camera.recording.currentStatus;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _toggleRecord() async {
    final session = _session;
    if (session == null || _recordBusy) {
      return;
    }
    final recorder = session.camera.recording;
    if (_recording.phase == IpCameraRecordingPhase.recording ||
        _recording.phase == IpCameraRecordingPhase.preparing ||
        _recording.phase == IpCameraRecordingPhase.stopping) {
      setState(() => _recordBusy = true);
      try {
        final result = await recorder.stop();
        if (!mounted) {
          return;
        }
        if (result != null) {
          setState(() => _lastSavedPath = result.outputPath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: ${result.outputPath}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stop error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _recordBusy = false);
        }
      }
      return;
    }

    final recordSource = session.previewPr0;
    if (_status.phase != IpCameraUiPhase.connected || recordSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not connected')),
      );
      return;
    }

    setState(() {
      _recordBusy = true;
      _lastSavedPath = null;
    });
    try {
      final path = widget.recordingPaths.nextMp4Path();
      final startFuture = recorder.start(IpCameraRecordingRequest(
        sourceCandidates: [recordSource],
        outputPath: path,
        codec: IpCameraVideoCodec.h264,
      ));
      // `start` emits preparing before its first await; release busy so Stop
      // can cancel while waiting for the first RTSP media.
      if (mounted) {
        setState(() => _recordBusy = false);
      }

      final status = await startFuture;
      if (!mounted) {
        return;
      }
      if (status.phase == IpCameraRecordingPhase.failed &&
          status.detail != 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Record failed${status.detail != null ? ': ${status.detail}' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Record error: $e')),
        );
      }
    } finally {
      if (mounted && _recordBusy) {
        setState(() => _recordBusy = false);
      }
    }
  }

  @override
  void dispose() {
    _routeSettleTimer?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_recSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final previewUrl = session?.previewPr0;
    final previewReady =
        (session?.previewReady ?? false) && _routeSettled;

    return SettingsScaffold(
      title: l10n.ipCameraText,
      body: SettingsScrollView(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SettingsSectionHeader('Status'),
          SettingsGroup(
            children: [
              ListTile(
                title: const Text('Connection'),
                subtitle: Text(_statusLabel(l10n, _status)),
                trailing: TextButton(
                  onPressed: session == null
                      ? null
                      : () => unawaited(session.retryNow()),
                  child: const Text('Retry'),
                ),
              ),
              SettingsValueRow(
                title: 'Camera IP',
                value: session?.camera.cameraHost ?? '—',
              ),
              SettingsValueRow(
                title: 'Preview URL',
                value: previewUrl?.toString() ?? '—',
              ),
              SettingsValueRow(
                title: 'MediaMTX',
                value: session?.relayStatus.phase.name ?? '—',
              ),
              if (session?.relayStatus.detail != null)
                SettingsValueRow(
                  title: 'MediaMTX detail',
                  value: session!.relayStatus.detail!,
                ),
            ],
          ),
          const SettingsSectionHeader('Preview'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IpCameraPreview(
                    rtspUrl: previewUrl,
                    linkPhase: _status.phase,
                    relayReady: previewReady,
                    playerFactory: widget.previewPlayerFactory,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                FilledButton(
                  key: const Key('ip-camera-record-button'),
                  onPressed: session == null || _recordBusy
                      ? null
                      : () => unawaited(_toggleRecord()),
                  child: Text(_recordButtonLabel(l10n)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _recordingHint(),
                    key: const Key('ip-camera-record-hint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (_lastSavedPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Saved: $_lastSavedPath',
                key: const Key('ip-camera-saved-path'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _recordButtonLabel(AppLocalizations l10n) {
    switch (_recording.phase) {
      case IpCameraRecordingPhase.preparing:
        return l10n.cancelText;
      case IpCameraRecordingPhase.recording:
      case IpCameraRecordingPhase.stopping:
        return 'Stop';
      case IpCameraRecordingPhase.idle:
      case IpCameraRecordingPhase.completed:
      case IpCameraRecordingPhase.failed:
        return 'Record';
    }
  }

  String _recordingHint() {
    switch (_recording.phase) {
      case IpCameraRecordingPhase.preparing:
        return 'Waiting for RTSP stream…';
      case IpCameraRecordingPhase.recording:
        return 'Recording…';
      case IpCameraRecordingPhase.stopping:
        return 'Finalizing…';
      case IpCameraRecordingPhase.failed:
        return _recording.detail ?? 'Recording failed';
      case IpCameraRecordingPhase.completed:
      case IpCameraRecordingPhase.idle:
        return 'Demo only — saves under /userdata/storage/Videos';
    }
  }

  String _statusLabel(AppLocalizations l10n, IpCameraUiStatus s) {
    switch (s.phase) {
      case IpCameraUiPhase.connecting:
        return 'Establishing… (attempt ${s.attempt})';
      case IpCameraUiPhase.connected:
        return l10n.connectedText;
      case IpCameraUiPhase.failed:
        return 'Failed${s.detail != null ? ': ${s.detail}' : ''}';
    }
  }
}
