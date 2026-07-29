import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_demo_recording_paths.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_video/application/process_video_save_handler.dart';
import 'package:lws_hmi/features/process_video/application/process_video_snapshot_source.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Shared Record Work arm + laser-synced IP-camera recording (Quick + Engineer).
///
/// Matches lws-ui [CameraController]: checkbox arms recording; encode starts
/// only while armed and laser enable is on. On successful stop, persists a
/// process-video row via [saveHandler] when [snapshotSource] supplied a start
/// snapshot.
///
/// 10-minute auto-segment roll (lws-ui [CameraConfig.DEFAULT_VIDEO_DURATION])
/// is deferred: HAL remux stop/restart while armed+laser is not yet validated
/// on ynh960; v1 keeps one continuous MP4 per laser session.
final class RecordWorkController extends ChangeNotifier {
  RecordWorkController({
    required this.deviceControl,
    this.recordingPaths = const IpCameraDemoRecordingPaths(),
    this.snapshotSource,
    this.saveHandler,
    this.onMessage,
  });

  final DeviceControlController deviceControl;
  final IpCameraDemoRecordingPaths recordingPaths;
  final ProcessVideoSnapshotSource? snapshotSource;
  final ProcessVideoSaveHandler? saveHandler;
  final ValueChanged<String>? onMessage;

  /// Defaults on (product default); cleared while camera is unreachable.
  bool _armed = true;
  bool _recordSyncInFlight = false;
  bool? _lastLaserActive;
  IpCameraUiPhase _cameraPhase = IpCameraUiPhase.connecting;
  IpCameraProductSession? _cameraSession;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;
  StreamSubscription<IpCameraRecordingStatus>? _recordingSub;
  bool _started = false;
  bool _disposed = false;
  ProcessVideoSnapshot? _startSnapshot;
  String? _activeOutputPath;
  DateTime? _recordingStartedAt;

  bool get armed => _armed;

  bool get enabled => _cameraPhase == IpCameraUiPhase.connected;

  IpCameraUiPhase get cameraPhase => _cameraPhase;

  /// Set only after media reaches the recorder. This deliberately excludes the
  /// RTSP preparation phase so the UI timer matches the saved video duration.
  DateTime? get recordingStartedAt => _recordingStartedAt;

  Duration recordingElapsedAt(DateTime now) {
    final startedAt = _recordingStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

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
      await _recordingSub?.cancel();
      _recordingSub = session.camera.recording.status.listen(
        _onRecordingStatus,
      );
      _onRecordingStatus(session.camera.recording.currentStatus);
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

  void _onRecordingStatus(IpCameraRecordingStatus status) {
    final next = status.phase == IpCameraRecordingPhase.recording
        ? status.startedAt
        : null;
    if (_recordingStartedAt == next) {
      return;
    }
    _recordingStartedAt = next;
    notifyListeners();
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
        await Directory(File(path).parent.path).create(recursive: true);
        _startSnapshot = snapshotSource?.capture();
        _activeOutputPath = path;
        await recorder.start(
          IpCameraRecordingRequest(
            sourceCandidates: [source],
            outputPath: path,
            codec: IpCameraVideoCodec.h264,
          ),
        );
      } catch (_) {
        _startSnapshot = null;
        _activeOutputPath = null;
        onMessage?.call(DeviceControlFeedbackCopy.cameraUnavailable);
      } finally {
        _recordSyncInFlight = false;
      }
      return;
    }
    if (recorder.currentStatus.isActive) {
      _recordSyncInFlight = true;
      try {
        final result = await recorder.stop();
        await _persistIfNeeded(result);
      } catch (_) {
        // Best-effort stop.
        _startSnapshot = null;
        _activeOutputPath = null;
      } finally {
        _recordSyncInFlight = false;
      }
    }
  }

  Future<void> _persistIfNeeded(IpCameraRecordingResult? result) async {
    final startSnap = _startSnapshot;
    final path = result?.outputPath ?? _activeOutputPath;
    _startSnapshot = null;
    _activeOutputPath = null;
    final handler = saveHandler;
    final source = snapshotSource;
    if (handler == null || source == null || result == null || path == null) {
      return;
    }
    if (startSnap == null) {
      return;
    }
    final snapshot = source.resolveAtSave(startSnap);
    final outcome = await handler.save(
      videoPath: path,
      snapshot: snapshot,
      bytesWritten: result.bytesWritten,
      startedAt: result.startedAt,
      completedAt: result.completedAt,
    );
    if (outcome == ProcessVideoSaveOutcome.discardedTooShort) {
      onMessage?.call('Recording too short — not saved');
    } else if (outcome == ProcessVideoSaveOutcome.discardedMissingFile ||
        outcome == ProcessVideoSaveOutcome.failed) {
      onMessage?.call('Failed to save recording');
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
    unawaited(_recordingSub?.cancel());
    super.dispose();
  }
}
