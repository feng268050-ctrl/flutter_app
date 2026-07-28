import 'dart:async';

import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';

/// Shared Record Work arm + laser-synced IP-camera recording (Quick + Engineer).
///
/// Matches lws-ui [CameraController]: checkbox arms recording; encode starts
/// only while armed and laser enable is on. AI-library metadata is deferred.
final class RecordWorkController extends ChangeNotifier {
  RecordWorkController({
    required this.deviceControl,
    this.recordingPaths = const IpCameraDemoRecordingPaths(),
    this.onMessage,
  });

  final DeviceControlController deviceControl;
  final IpCameraDemoRecordingPaths recordingPaths;
  final ValueChanged<String>? onMessage;

  /// Defaults on (product default); cleared while camera is unreachable.
  bool _armed = true;
  bool _recordSyncInFlight = false;
  bool? _lastLaserActive;
  IpCameraUiPhase _cameraPhase = IpCameraUiPhase.connecting;
  IpCameraProductSession? _cameraSession;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;
  bool _started = false;
  bool _disposed = false;

  bool get armed => _armed;

  bool get enabled => _cameraPhase == IpCameraUiPhase.connected;

  IpCameraUiPhase get cameraPhase => _cameraPhase;

  /// Bind camera session and laser listener. Idempotent.
  ///
  /// Does not call [IpCameraProductSession.start] — product boot / status bar
  /// owns that. We only mirror UI phase so Record Work can arm when healthy.
  Future<void> start(AppServices? services) async {
    if (_disposed || _started) {
      return;
    }
    _started = true;
    deviceControl.addListener(_onDeviceControlChanged);
    // lws-ui CameraController: encode while laser enable session is on.
    _lastLaserActive = deviceControl.laserSessionArmed;

    if (services == null) {
      _cameraPhase = IpCameraUiPhase.failed;
      _armed = false;
      notifyListeners();
      return;
    }
    try {
      final session = await services.ensureIpCamera();
      if (_disposed) {
        return;
      }
      _cameraSession = session;
      _applyCameraPhase(session.currentStatus.phase);
      notifyListeners();
      await _cameraSub?.cancel();
      _cameraSub = session.status.listen(_onCameraStatus);
      await _syncRecordingWithArmedAndLaser();
    } catch (_) {
      if (_disposed) {
        return;
      }
      _cameraPhase = IpCameraUiPhase.failed;
      _armed = false;
      notifyListeners();
    }
  }

  Future<void> setArmed(bool value) async {
    if (!enabled || _disposed) {
      return;
    }
    if (_armed == value) {
      return;
    }
    _armed = value;
    notifyListeners();
    await _syncRecordingWithArmedAndLaser();
  }

  /// Mode exit (lws-ui `tryStopRecord`): disarm and stop any active encode.
  Future<void> stopRecordingForExit() async {
    if (_disposed) {
      return;
    }
    if (_armed) {
      _armed = false;
      notifyListeners();
    }
    await _syncRecordingWithArmedAndLaser();
  }

  void _onDeviceControlChanged() {
    if (_disposed) {
      return;
    }
    final laserActive = deviceControl.laserSessionArmed;
    if (_lastLaserActive == laserActive) {
      return;
    }
    _lastLaserActive = laserActive;
    unawaited(_syncRecordingWithArmedAndLaser());
  }

  void _applyCameraPhase(IpCameraUiPhase phase) {
    final wasConnected = _cameraPhase == IpCameraUiPhase.connected;
    _cameraPhase = phase;
    if (phase != IpCameraUiPhase.connected) {
      _armed = false;
      return;
    }
    // Fresh (re)connect restores product default (armed on).
    if (!wasConnected) {
      _armed = true;
    }
  }

  void _onCameraStatus(IpCameraUiStatus status) {
    if (_disposed) {
      return;
    }
    final wasHealthy = _cameraPhase == IpCameraUiPhase.connected;
    _applyCameraPhase(status.phase);
    notifyListeners();
    final healthy = status.phase == IpCameraUiPhase.connected;
    if (!healthy || (!wasHealthy && healthy)) {
      unawaited(_syncRecordingWithArmedAndLaser());
    }
  }

  /// Start when Record Work is armed and laser enable is on; stop otherwise.
  Future<void> _syncRecordingWithArmedAndLaser() async {
    if (_recordSyncInFlight || _disposed) {
      return;
    }
    final session = _cameraSession;
    if (session == null) {
      return;
    }
    final recorder = session.camera.recording;
    final laserActive = deviceControl.laserSessionArmed;
    if (_armed && laserActive) {
      if (recorder.currentStatus.isActive) {
        return;
      }
      final source = session.previewPr0;
      if (_cameraPhase != IpCameraUiPhase.connected || source == null) {
        onMessage?.call(DeviceControlFeedbackCopy.cameraUnavailable);
        return;
      }
      _recordSyncInFlight = true;
      try {
        final path = recordingPaths.nextMp4Path();
        await recorder.start(
          IpCameraRecordingRequest(
            sourceCandidates: [source],
            outputPath: path,
            codec: IpCameraVideoCodec.h264,
          ),
        );
      } catch (_) {
        onMessage?.call(DeviceControlFeedbackCopy.cameraUnavailable);
      } finally {
        _recordSyncInFlight = false;
      }
      return;
    }
    if (recorder.currentStatus.isActive) {
      _recordSyncInFlight = true;
      try {
        await recorder.stop();
      } catch (_) {
        // Best-effort stop.
      } finally {
        _recordSyncInFlight = false;
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    deviceControl.removeListener(_onDeviceControlChanged);
    unawaited(_cameraSub?.cancel());
    super.dispose();
  }
}
