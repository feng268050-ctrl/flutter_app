import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'restart_policy.dart';

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment,
  bool runInShell,
});

typedef ProcessLogSink = void Function(String line);

/// Supervises one long-lived child process with optional restart and log drain.
final class ProcessSupervisor {
  ProcessSupervisor({
    this.restartPolicy = RestartPolicy.none,
    ProcessStarter? startProcess,
    ProcessLogSink? logSink,
  })  : _startProcess = startProcess ?? Process.start,
        _logSink = logSink ?? _defaultLogSink;

  final RestartPolicy restartPolicy;
  final ProcessStarter _startProcess;
  final ProcessLogSink _logSink;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<List<int>>? _stderrSub;
  Future<void>? _exitWatch;
  bool _wanted = false;
  bool _stopping = false;
  int _burst = 0;
  Timer? _restartTimer;
  String _logPrefix = 'child';
  String? _exe;
  List<String> _args = const <String>[];
  String? _workingDirectory;
  Map<String, String>? _environment;

  bool get isRunning {
    final p = _process;
    return p != null;
  }

  /// Spawns (or no-ops if already running with the same wanted state).
  Future<void> start({
    required String executable,
    List<String> arguments = const <String>[],
    String? workingDirectory,
    Map<String, String>? environment,
    String logPrefix = 'child',
  }) async {
    _wanted = true;
    _stopping = false;
    _burst = 0;
    _restartTimer?.cancel();
    _restartTimer = null;
    _logPrefix = logPrefix;
    _exe = executable;
    _args = List<String>.from(arguments);
    _workingDirectory = workingDirectory;
    _environment = environment == null
        ? null
        : Map<String, String>.from(environment);

    if (_process != null) {
      return;
    }
    await _spawn();
  }

  Future<void> stop({Duration killGrace = const Duration(seconds: 2)}) async {
    _wanted = false;
    _stopping = true;
    _restartTimer?.cancel();
    _restartTimer = null;
    _burst = 0;
    final p = _process;
    if (p == null) {
      _stopping = false;
      return;
    }
    await _detachStreams();
    try {
      p.kill(ProcessSignal.sigterm);
    } catch (_) {}
    try {
      await p.exitCode.timeout(killGrace);
    } on TimeoutException {
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
      try {
        await p.exitCode;
      } catch (_) {}
    } catch (_) {}
    _process = null;
    _exitWatch = null;
    _stopping = false;
  }

  Future<void> _spawn() async {
    final exe = _exe;
    if (exe == null) {
      throw StateError('ProcessSupervisor.start requires executable');
    }
    final process = await _startProcess(
      exe,
      _args,
      workingDirectory: _workingDirectory,
      environment: _environment,
      includeParentEnvironment: true,
      runInShell: false,
    );
    _process = process;
    _attachStreams(process);
    _exitWatch = _watchExit(process);
  }

  void _attachStreams(Process process) {
    final decoder = const Utf8Decoder(allowMalformed: true);
    _stdoutSub = process.stdout.listen((chunk) {
      _emitChunks(decoder.convert(chunk));
    });
    _stderrSub = process.stderr.listen((chunk) {
      _emitChunks(decoder.convert(chunk));
    });
  }

  String _lineBuf = '';

  void _emitChunks(String text) {
    _lineBuf += text;
    while (true) {
      final i = _lineBuf.indexOf('\n');
      if (i < 0) {
        break;
      }
      var line = _lineBuf.substring(0, i);
      _lineBuf = _lineBuf.substring(i + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      _logSink('$_logPrefix: $line');
    }
  }

  Future<void> _detachStreams() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    if (_lineBuf.isNotEmpty) {
      _logSink('$_logPrefix: $_lineBuf');
      _lineBuf = '';
    }
  }

  Future<void> _watchExit(Process process) async {
    int code;
    try {
      code = await process.exitCode;
    } catch (_) {
      code = -1;
    }
    if (!identical(_process, process)) {
      return;
    }
    await _detachStreams();
    _process = null;
    _logSink('$_logPrefix: exit code=$code');
    if (!_wanted || _stopping) {
      return;
    }
    final policy = restartPolicy;
    if (policy is! RestartOnFailure) {
      return;
    }
    _burst += 1;
    final max = policy.maxBurst;
    if (max != null && _burst > max) {
      _logSink('$_logPrefix: restart burst exceeded ($max); giving up');
      _wanted = false;
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = Timer(policy.delay, () {
      if (!_wanted || _process != null) {
        return;
      }
      unawaited(() async {
        try {
          await _spawn();
        } catch (e) {
          _logSink('$_logPrefix: respawn failed: $e');
          if (!_wanted) {
            return;
          }
          _burst += 1;
          final maxBurst = policy.maxBurst;
          if (maxBurst != null && _burst > maxBurst) {
            _logSink(
                '$_logPrefix: restart burst exceeded ($maxBurst); giving up');
            _wanted = false;
            return;
          }
          _restartTimer = Timer(policy.delay, () {
            if (_wanted && _process == null) {
              unawaited(_spawn().catchError((Object err) {
                _logSink('$_logPrefix: respawn failed: $err');
              }));
            }
          });
        }
      }());
    });
  }

  static void _defaultLogSink(String line) {
    // ignore: avoid_print
    print(line);
  }
}
