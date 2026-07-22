import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/src/ip_camera/ip_camera_recording.dart';
import 'package:flutter/foundation.dart';

/// Spawns a GStreamer recording pipeline. Injected in tests.
typedef IpCameraGstProcessFactory = Future<IpCameraGstProcess> Function({
  required List<String> arguments,
  Map<String, String>? environment,
});

/// Minimal process handle used by [LinuxIpCameraRecordingController].
abstract interface class IpCameraGstProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
  bool get isRunning;

  /// Ask `gst-launch -e` to finalize (SIGINT).
  void interrupt();

  Future<void> kill();
}

final class _DartIpCameraGstProcess implements IpCameraGstProcess {
  _DartIpCameraGstProcess(this._process);

  final Process _process;
  bool _running = true;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode async {
    final code = await _process.exitCode;
    _running = false;
    return code;
  }

  @override
  bool get isRunning => _running;

  @override
  void interrupt() {
    if (!_running) {
      return;
    }
    _process.kill(ProcessSignal.sigint);
  }

  @override
  Future<void> kill() async {
    if (!_running) {
      return;
    }
    _process.kill(ProcessSignal.sigkill);
    try {
      await _process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}
    _running = false;
  }
}

/// Linux RTSP→MP4 recorder: preparing until first media, then recording.
final class LinuxIpCameraRecordingController
    implements IpCameraRecordingController {
  LinuxIpCameraRecordingController({
    IpCameraGstProcessFactory? processFactory,
    this.gstLaunchBinary = 'gst-launch-1.0',
    this.minReadyBytes = 1024,
  }) : _processFactory = processFactory;

  final IpCameraGstProcessFactory? _processFactory;
  final String gstLaunchBinary;

  /// File growth threshold used with ASYNC_DONE as readiness confirmation.
  final int minReadyBytes;

  Future<IpCameraGstProcess> _spawn({
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    final factory = _processFactory;
    if (factory != null) {
      return factory(arguments: arguments, environment: environment);
    }
    return _defaultProcessFactory(
      binary: gstLaunchBinary,
      arguments: arguments,
      environment: environment,
    );
  }

  final _statusCtrl = StreamController<IpCameraRecordingStatus>.broadcast();
  IpCameraRecordingStatus _status = IpCameraRecordingStatus(
    phase: IpCameraRecordingPhase.idle,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Completer<IpCameraRecordingStatus>? _startCompleter;
  Completer<IpCameraRecordingResult?>? _stopCompleter;
  IpCameraGstProcess? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Timer? _readyPoll;
  IpCameraRecordingRequest? _activeRequest;
  DateTime? _startedAt;
  bool _readySeen = false;
  bool _disposed = false;
  int _generation = 0;

  @override
  Stream<IpCameraRecordingStatus> get status => _statusCtrl.stream;

  @override
  IpCameraRecordingStatus get currentStatus => _status;

  @override
  Future<IpCameraRecordingStatus> start(IpCameraRecordingRequest request) async {
    _ensureNotDisposed();
    if (_status.isActive) {
      throw StateError('recording already active (${_status.phase.name})');
    }
    if (request.sourceCandidates.isEmpty) {
      throw ArgumentError.value(
        request.sourceCandidates,
        'sourceCandidates',
        'must not be empty',
      );
    }
    if (request.outputPath.trim().isEmpty) {
      throw ArgumentError.value(request.outputPath, 'outputPath', 'required');
    }

    final completer = Completer<IpCameraRecordingStatus>();
    _startCompleter = completer;
    _activeRequest = request;
    _startedAt = null;
    _readySeen = false;
    final gen = ++_generation;

    _emit(IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.preparing,
      outputPath: request.outputPath,
      updatedAt: DateTime.now(),
    ));

    unawaited(_runPrepareLoop(request, gen));
    return completer.future;
  }

  @override
  Future<IpCameraRecordingResult?> stop() async {
    _ensureNotDisposed();
    if (!_status.isActive) {
      return null;
    }
    if (_stopCompleter != null) {
      return _stopCompleter!.future;
    }

    final completer = Completer<IpCameraRecordingResult?>();
    _stopCompleter = completer;
    final request = _activeRequest;
    final startedAt = _startedAt;
    final gen = _generation;

    if (_status.phase == IpCameraRecordingPhase.preparing) {
      await _abortPreparing(
        gen: gen,
        detail: 'cancelled',
        completeStartAsFailed: true,
      );
      completer.complete(null);
      _stopCompleter = null;
      return null;
    }

    _emit(IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.stopping,
      outputPath: request?.outputPath,
      startedAt: startedAt,
      updatedAt: DateTime.now(),
    ));

    final process = _process;
    final finalizeTimeout =
        request?.finalizeTimeout ?? const Duration(seconds: 10);
    if (process != null && process.isRunning) {
      process.interrupt();
      try {
        await process.exitCode.timeout(finalizeTimeout);
      } catch (_) {
        await process.kill();
      }
    }
    await _detachProcess();

    final path = request?.outputPath;
    final file = path == null ? null : File(path);
    final bytes = (file != null && await file.exists()) ? await file.length() : 0;
    if (path != null && bytes > 0 && startedAt != null) {
      final result = IpCameraRecordingResult(
        outputPath: path,
        bytesWritten: bytes,
        startedAt: startedAt,
        completedAt: DateTime.now(),
      );
      _emit(IpCameraRecordingStatus(
        phase: IpCameraRecordingPhase.completed,
        outputPath: path,
        startedAt: startedAt,
        updatedAt: DateTime.now(),
      ));
      _resetToIdleSoon();
      completer.complete(result);
    } else {
      await _deleteIfExists(path);
      _emit(IpCameraRecordingStatus(
        phase: IpCameraRecordingPhase.failed,
        outputPath: path,
        detail: 'finalize_failed',
        startedAt: startedAt,
        updatedAt: DateTime.now(),
      ));
      _resetToIdleSoon();
      completer.complete(null);
    }
    _stopCompleter = null;
    _activeRequest = null;
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _readyPoll?.cancel();
    if (_status.isActive) {
      await _abortPreparing(
        gen: _generation,
        detail: 'disposed',
        completeStartAsFailed: true,
        forceKill: true,
      );
    }
    await _detachProcess();
    await _statusCtrl.close();
  }

  Future<void> _runPrepareLoop(
    IpCameraRecordingRequest request,
    int gen,
  ) async {
    final deadline = DateTime.now().add(request.readyTimeout);
    var index = 0;
    try {
      await _ensureParentDir(request.outputPath);
      while (!_disposed && gen == _generation) {
        if (DateTime.now().isAfter(deadline)) {
          await _failStart(gen, 'ready_timeout');
          return;
        }
        if (_status.phase != IpCameraRecordingPhase.preparing) {
          return;
        }

        final source =
            request.sourceCandidates[index % request.sourceCandidates.length];
        index++;
        await _deleteIfExists(request.outputPath);

        final args = _buildGstArgs(request, source);
        debugPrint('ip_camera.record: preparing $source → ${request.outputPath}');
        final process = await _spawn(
          arguments: args,
          environment: const <String, String>{
            // Keep bus messages readable without flooding.
            'GST_DEBUG': '2',
          },
        );
        if (gen != _generation || _disposed) {
          await process.kill();
          return;
        }
        _process = process;
        _readySeen = false;
        _attachProcessLogs(process, gen);

        final perAttempt = Duration(
          milliseconds: (request.readyTimeout.inMilliseconds ~/
                  request.sourceCandidates.length.clamp(1, 8))
              .clamp(3000, request.readyTimeout.inMilliseconds),
        );
        final ready = await _waitUntilReady(
          request: request,
          process: process,
          gen: gen,
          attemptDeadline: DateTime.now().add(perAttempt),
        );
        if (gen != _generation || _disposed) {
          return;
        }
        if (ready) {
          _startedAt = DateTime.now();
          final status = IpCameraRecordingStatus(
            phase: IpCameraRecordingPhase.recording,
            outputPath: request.outputPath,
            startedAt: _startedAt,
            updatedAt: DateTime.now(),
          );
          _emit(status);
          final c = _startCompleter;
          _startCompleter = null;
          if (c != null && !c.isCompleted) {
            c.complete(status);
          }
          unawaited(_watchProcessWhileRecording(process, gen));
          return;
        }

        await _detachProcess();
        await _deleteIfExists(request.outputPath);
        if (DateTime.now().isAfter(deadline)) {
          await _failStart(gen, 'ready_timeout');
          return;
        }
        await Future<void>.delayed(request.retryDelay);
      }
    } catch (e, st) {
      debugPrint('ip_camera.record: prepare error: $e\n$st');
      if (gen == _generation) {
        await _failStart(gen, '$e');
      }
    }
  }

  Future<bool> _waitUntilReady({
    required IpCameraRecordingRequest request,
    required IpCameraGstProcess process,
    required int gen,
    required DateTime attemptDeadline,
  }) async {
    final ready = Completer<bool>();
    void maybeComplete(bool value) {
      if (!ready.isCompleted) {
        ready.complete(value);
      }
    }

    final exitSub = Stream<int>.fromFuture(process.exitCode).listen((_) {
      maybeComplete(false);
    });

    _readyPoll?.cancel();
    _readyPoll = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (gen != _generation || _disposed) {
        maybeComplete(false);
        return;
      }
      if (DateTime.now().isAfter(attemptDeadline)) {
        maybeComplete(false);
        return;
      }
      if (_readySeen) {
        maybeComplete(true);
        return;
      }
      final file = File(request.outputPath);
      if (await file.exists()) {
        final len = await file.length();
        if (len >= minReadyBytes) {
          maybeComplete(true);
        }
      }
    });

    try {
      return await ready.future;
    } finally {
      await exitSub.cancel();
      _readyPoll?.cancel();
      _readyPoll = null;
    }
  }

  Future<void> _watchProcessWhileRecording(
    IpCameraGstProcess process,
    int gen,
  ) async {
    final code = await process.exitCode;
    if (_disposed || gen != _generation) {
      return;
    }
    if (_status.phase != IpCameraRecordingPhase.recording) {
      return;
    }
    debugPrint('ip_camera.record: unexpected exit code=$code');
    await _detachProcess();
    await _deleteIfExists(_activeRequest?.outputPath);
    _emit(IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.failed,
      outputPath: _activeRequest?.outputPath,
      detail: 'pipeline_exited_$code',
      startedAt: _startedAt,
      updatedAt: DateTime.now(),
    ));
    _activeRequest = null;
    _resetToIdleSoon();
  }

  void _attachProcessLogs(IpCameraGstProcess process, int gen) {
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (gen != _generation) {
        return;
      }
      if (_looksLikeReady(line)) {
        _readySeen = true;
      }
    });
    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (gen != _generation) {
        return;
      }
      if (_looksLikeReady(line)) {
        _readySeen = true;
      }
      if (line.toLowerCase().contains('error') ||
          line.toLowerCase().contains('not-negotiated') ||
          line.toLowerCase().contains('failed')) {
        debugPrint('ip_camera.record: $line');
      }
    });
  }

  bool _looksLikeReady(String line) {
    final lower = line.toLowerCase();
    return lower.contains('async-done') ||
        lower.contains('prerolled') ||
        lower.contains('async_done');
  }

  List<String> _buildGstArgs(IpCameraRecordingRequest request, Uri source) {
    final depay = request.codec == IpCameraVideoCodec.h265
        ? 'rtph265depay'
        : 'rtph264depay';
    final parse =
        request.codec == IpCameraVideoCodec.h265 ? 'h265parse' : 'h264parse';
    // Encoded remux only — no decode. -e enables EOS finalize on SIGINT.
    // Pass pipeline tokens as separate argv (not one string): a single
    // `location=rtsp://…` token inside one argv hits gst-launch parse
    // "syntax error" on this Buildroot GStreamer.
    return <String>[
      '-e',
      '-q',
      '-m',
      'rtspsrc',
      'location=${source.toString()}',
      'protocols=tcp',
      'latency=200',
      '!',
      depay,
      '!',
      parse,
      '!',
      'mp4mux',
      '!',
      'filesink',
      'location=${request.outputPath}',
    ];
  }

  Future<void> _failStart(int gen, String detail) async {
    if (gen != _generation) {
      return;
    }
    await _detachProcess();
    await _deleteIfExists(_activeRequest?.outputPath);
    final status = IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.failed,
      outputPath: _activeRequest?.outputPath,
      detail: detail,
      updatedAt: DateTime.now(),
    );
    _emit(status);
    final c = _startCompleter;
    _startCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete(status);
    }
    _activeRequest = null;
    _resetToIdleSoon();
  }

  Future<void> _abortPreparing({
    required int gen,
    required String detail,
    required bool completeStartAsFailed,
    bool forceKill = false,
  }) async {
    _generation++; // invalidate prepare loop
    final process = _process;
    if (process != null) {
      if (forceKill) {
        await process.kill();
      } else {
        process.interrupt();
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } catch (_) {
          await process.kill();
        }
      }
    }
    await _detachProcess();
    await _deleteIfExists(_activeRequest?.outputPath);
    final status = IpCameraRecordingStatus(
      phase: IpCameraRecordingPhase.failed,
      outputPath: _activeRequest?.outputPath,
      detail: detail,
      updatedAt: DateTime.now(),
    );
    _emit(status);
    if (completeStartAsFailed) {
      final c = _startCompleter;
      _startCompleter = null;
      if (c != null && !c.isCompleted) {
        c.complete(status);
      }
    }
    _activeRequest = null;
    _resetToIdleSoon();
  }

  Future<void> _detachProcess() async {
    _readyPoll?.cancel();
    _readyPoll = null;
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _process = null;
    _readySeen = false;
  }

  void _resetToIdleSoon() {
    // Keep terminal completed/failed briefly for UI, then return to idle.
    scheduleMicrotask(() {
      if (_disposed || _status.isActive) {
        return;
      }
      if (_status.phase == IpCameraRecordingPhase.completed ||
          _status.phase == IpCameraRecordingPhase.failed) {
        _emit(IpCameraRecordingStatus(
          phase: IpCameraRecordingPhase.idle,
          updatedAt: DateTime.now(),
        ));
      }
    });
  }

  void _emit(IpCameraRecordingStatus next) {
    if (_disposed || _statusCtrl.isClosed) {
      return;
    }
    final phaseChanged = next.phase != _status.phase;
    final detailChanged = next.detail != _status.detail;
    final pathChanged = next.outputPath != _status.outputPath;
    _status = next;
    if (phaseChanged || detailChanged || pathChanged) {
      _statusCtrl.add(next);
    }
  }

  Future<void> _ensureParentDir(String path) async {
    final parent = File(path).parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
  }

  Future<void> _deleteIfExists(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('IpCameraRecordingController disposed');
    }
  }

  static Future<IpCameraGstProcess> _defaultProcessFactory({
    required String binary,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    final process = await Process.start(
      binary,
      arguments,
      environment: environment,
      mode: ProcessStartMode.normal,
    );
    return _DartIpCameraGstProcess(process);
  }
}
