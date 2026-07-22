import 'dart:async';

import 'package:cyber_hal/src/ip_camera/ip_camera_controller.dart';
import 'package:cyber_hal/src/ip_camera/ip_camera_models.dart';
import 'package:cyber_hal/src/ip_camera/ip_camera_recording.dart';

/// In-memory [IpCameraController] for host tests / emulator.
final class StubIpCameraController implements IpCameraController {
  StubIpCameraController({
    required String cameraHost,
    IpCameraStreamPaths streamPaths = const IpCameraStreamPaths.pr01(),
    IpCameraHealthPhase initialPhase = IpCameraHealthPhase.unknown,
    IpCameraRecordingController? recording,
  })  : cameraHost = cameraHost.trim(),
        streams = IpCameraStreams.fromHost(
          cameraHost.trim(),
          paths: streamPaths,
        ),
        recording = recording ?? StubIpCameraRecordingController(),
        _health = IpCameraHealth(
          phase: initialPhase,
          updatedAt: DateTime.now(),
        );

  @override
  final String cameraHost;

  @override
  final IpCameraStreams streams;

  @override
  final IpCameraRecordingController recording;

  final _healthCtrl = StreamController<IpCameraHealth>.broadcast();
  IpCameraHealth _health;
  bool _disposed = false;

  @override
  Stream<IpCameraHealth> get health => _healthCtrl.stream;

  @override
  IpCameraHealth get currentHealth => _health;

  /// Test helper: force a health phase emission.
  void setHealth(IpCameraHealthPhase phase, {String? detail}) {
    _ensureNotDisposed();
    final next = IpCameraHealth(
      phase: phase,
      detail: detail,
      updatedAt: DateTime.now(),
    );
    _health = next;
    if (!_healthCtrl.isClosed) {
      _healthCtrl.add(next);
    }
  }

  @override
  Future<void> startMonitoring() async {}

  @override
  Future<IpCameraHealth> probeOnce() async => _health;

  @override
  void suspendProbes() {}

  @override
  void resumeProbes({bool? configurePingOk}) {}

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await recording.dispose();
    await _healthCtrl.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('StubIpCameraController disposed');
    }
  }
}

/// In-memory recorder for host tests: readiness is explicit via [markReady].
final class StubIpCameraRecordingController
    implements IpCameraRecordingController {
  StubIpCameraRecordingController({
    this.autoReadyAfter,
  });

  /// When set, automatically transition preparing → recording after this delay.
  final Duration? autoReadyAfter;

  final _statusCtrl = StreamController<IpCameraRecordingStatus>.broadcast();
  IpCameraRecordingStatus _status = IpCameraRecordingStatus(
    phase: IpCameraRecordingPhase.idle,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Completer<IpCameraRecordingStatus>? _startCompleter;
  IpCameraRecordingRequest? _request;
  DateTime? _startedAt;
  Timer? _autoReady;
  bool _disposed = false;
  int _bytesWritten = 0;

  @override
  Stream<IpCameraRecordingStatus> get status => _statusCtrl.stream;

  @override
  IpCameraRecordingStatus get currentStatus => _status;

  /// Simulate muxer first-media readiness (required unless [autoReadyAfter]).
  void markReady({int bytesWritten = 4096}) {
    _ensureNotDisposed();
    if (_status.phase != IpCameraRecordingPhase.preparing) {
      return;
    }
    _bytesWritten = bytesWritten;
    _startedAt = DateTime.now();
    final status = IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.recording,
      outputPath: _request?.outputPath,
      startedAt: _startedAt,
      updatedAt: DateTime.now(),
    );
    _emit(status);
    final c = _startCompleter;
    _startCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete(status);
    }
  }

  /// Force a prepare failure (e.g. timeout / candidate fail).
  void failPreparing([String detail = 'ready_timeout']) {
    _ensureNotDisposed();
    if (_status.phase != IpCameraRecordingPhase.preparing) {
      return;
    }
    _autoReady?.cancel();
    final status = IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.failed,
      outputPath: _request?.outputPath,
      detail: detail,
      updatedAt: DateTime.now(),
    );
    _emit(status);
    final c = _startCompleter;
    _startCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete(status);
    }
    _request = null;
    _emitIdleSoon();
  }

  @override
  Future<IpCameraRecordingStatus> start(IpCameraRecordingRequest request) async {
    _ensureNotDisposed();
    if (_status.isActive) {
      throw StateError('recording already active');
    }
    final completer = Completer<IpCameraRecordingStatus>();
    _startCompleter = completer;
    _request = request;
    _bytesWritten = 0;
    _startedAt = null;
    _emit(IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.preparing,
      outputPath: request.outputPath,
      updatedAt: DateTime.now(),
    ));
    final delay = autoReadyAfter;
    if (delay != null) {
      _autoReady?.cancel();
      _autoReady = Timer(delay, markReady);
    }
    return completer.future;
  }

  @override
  Future<IpCameraRecordingResult?> stop() async {
    _ensureNotDisposed();
    if (!_status.isActive) {
      return null;
    }
    _autoReady?.cancel();
    if (_status.phase == IpCameraRecordingPhase.preparing) {
      final status = IpCameraRecordingStatus(
        phase: IpCameraRecordingPhase.failed,
        outputPath: _request?.outputPath,
        detail: 'cancelled',
        updatedAt: DateTime.now(),
      );
      _emit(status);
      final c = _startCompleter;
      _startCompleter = null;
      if (c != null && !c.isCompleted) {
        c.complete(status);
      }
      _request = null;
      _emitIdleSoon();
      return null;
    }

    _emit(IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.stopping,
      outputPath: _request?.outputPath,
      startedAt: _startedAt,
      updatedAt: DateTime.now(),
    ));
    final path = _request?.outputPath;
    final startedAt = _startedAt;
    if (path != null && startedAt != null && _bytesWritten > 0) {
      final result = IpCameraRecordingResult(
        outputPath: path,
        bytesWritten: _bytesWritten,
        startedAt: startedAt,
        completedAt: DateTime.now(),
      );
      _emit(IpCameraRecordingStatus(
        phase: IpCameraRecordingPhase.completed,
        outputPath: path,
        startedAt: startedAt,
        updatedAt: DateTime.now(),
      ));
      _request = null;
      _emitIdleSoon();
      return result;
    }
    _emit(IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.failed,
      outputPath: path,
      detail: 'finalize_failed',
      startedAt: startedAt,
      updatedAt: DateTime.now(),
    ));
    _request = null;
    _emitIdleSoon();
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _autoReady?.cancel();
    if (_status.isActive) {
      await stop();
    }
    _disposed = true;
    await _statusCtrl.close();
  }

  void _emitIdleSoon() {
    scheduleMicrotask(() {
      if (_disposed || _status.isActive) {
        return;
      }
      _emit(IpCameraRecordingStatus(
        phase: IpCameraRecordingPhase.idle,
        updatedAt: DateTime.now(),
      ));
    });
  }

  void _emit(IpCameraRecordingStatus next) {
    if (_disposed || _statusCtrl.isClosed) {
      return;
    }
    _status = next;
    _statusCtrl.add(next);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('StubIpCameraRecordingController disposed');
    }
  }
}
