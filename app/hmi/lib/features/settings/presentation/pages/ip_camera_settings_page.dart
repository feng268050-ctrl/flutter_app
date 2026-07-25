import 'dart:async';

import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_mediamtx_relay.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/ip_camera/presentation/ip_camera_preview.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Common Settings → Camera: Status / Type / Version + live preview + demo record.
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

  String? _cameraTypeRaw;
  String _cameraVersion = kUnavailableDisplay;
  final _versionCache = CameraDeviceInfoCache();

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
      final product = await widget.services.ensureProductInfo();
      if (mounted) {
        setState(() => _cameraTypeRaw = product.cameraType());
      }
      final host = product.cameraIp();
      if (host.isNotEmpty) {
        final version = await _versionCache.fetch(host);
        if (mounted) setState(() => _cameraVersion = version);
      }
    } catch (_) {}

    try {
      final session = await widget.services.ensureIpCamera();
      if (!mounted) {
        return;
      }
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
      final host = session.camera.cameraHost;
      if (host.isNotEmpty) {
        final version = await _versionCache.fetch(host);
        if (mounted) setState(() => _cameraVersion = version);
      }
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
    _versionCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final previewUrl = session?.previewPr0;
    final previewReady = (session?.previewReady ?? false) && _routeSettled;
    final typeLabel = productCameraTypeDisplayLocalized(
      _cameraTypeRaw,
      blueLight: l10n.cameraTypeBlueLight,
      redLight: l10n.cameraTypeRedLight,
    );

    return SettingsScaffold(
      title: l10n.ipCameraText,
      body: SettingsScrollView(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          // Status / Type / Version
          SettingsGroup(
            children: [
              SettingsValueRow(
                title: l10n.cameraStatus,
                value: _statusLabel(l10n, _status, session?.relayStatus),
              ),
              SettingsValueRow(
                title: l10n.cameraType,
                value: typeLabel,
              ),
              SettingsValueRow(
                title: l10n.cameraVersion,
                value: _cameraVersion,
              ),
            ],
          ),
          // Preview
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

  String _statusLabel(
    AppLocalizations l10n,
    IpCameraUiStatus s,
    IpCameraRelayStatus? relay,
  ) {
    if (s.phase == IpCameraUiPhase.failed) {
      final detail = s.detail;
      return detail == null || detail.isEmpty
          ? l10n.cameraStatusFailed
          : '${l10n.cameraStatusFailed}: $detail';
    }
    if (s.phase == IpCameraUiPhase.connecting) {
      return l10n.cameraStatusEstablishing;
    }
    switch (relay?.phase) {
      case IpCameraRelayPhase.running:
        return l10n.connectedText;
      case IpCameraRelayPhase.starting:
      case IpCameraRelayPhase.stopped:
        return l10n.cameraStatusEstablishing;
      case IpCameraRelayPhase.error:
        final detail = relay?.detail;
        return detail == null || detail.isEmpty
            ? l10n.cameraStatusFailed
            : '${l10n.cameraStatusFailed}: $detail';
      case null:
        return l10n.connectedText;
    }
  }
}
