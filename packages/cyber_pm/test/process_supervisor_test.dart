import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_pm/cyber_pm.dart';
import 'package:test/test.dart';

final class _FakeProcess implements Process {
  _FakeProcess({this.exitAfter}) {
    if (exitAfter != null) {
      Timer(exitAfter!, () {
        if (!_exit.isCompleted) {
          _exit.complete(1);
        }
      });
    }
  }

  final Duration? exitAfter;
  final _exit = Completer<int>();
  final _stdoutCtrl = StreamController<List<int>>();
  final _stderrCtrl = StreamController<List<int>>();
  var killed = false;

  void pushStdout(String line) {
    _stdoutCtrl.add(utf8.encode('$line\n'));
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) {
      _exit.complete(-15);
    }
    return true;
  }

  @override
  int get pid => 4242;

  @override
  Stream<List<int>> get stderr => _stderrCtrl.stream;

  @override
  IOSink get stdin => throw UnsupportedError('stdin');

  @override
  Stream<List<int>> get stdout => _stdoutCtrl.stream;
}

void main() {
  test('start drains prefixed logs and stop kills', () async {
    final logs = <String>[];
    late _FakeProcess fake;
    final sup = ProcessSupervisor(
      logSink: logs.add,
      startProcess: (exe, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false}) async {
        fake = _FakeProcess();
        return fake;
      },
    );

    await sup.start(executable: '/bin/mediamtx', arguments: const ['cfg'], logPrefix: 'mediamtx');
    expect(sup.isRunning, isTrue);
    fake.pushStdout('ready');
    await Future<void>.delayed(Duration.zero);
    expect(logs, contains('mediamtx: ready'));

    await sup.stop();
    expect(fake.killed, isTrue);
    expect(sup.isRunning, isFalse);
  });

  test('onFailure respawns after exit', () async {
    var starts = 0;
    final logs = <String>[];
    final sup = ProcessSupervisor(
      restartPolicy: const RestartPolicy.onFailure(delay: Duration(milliseconds: 20)),
      logSink: logs.add,
      startProcess: (exe, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false}) async {
        starts += 1;
        return _FakeProcess(exitAfter: const Duration(milliseconds: 5));
      },
    );

    await sup.start(executable: '/bin/x', logPrefix: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(starts, greaterThanOrEqualTo(2));
    await sup.stop();
  });

  test('maxBurst stops respawn', () async {
    var starts = 0;
    final sup = ProcessSupervisor(
      restartPolicy: const RestartPolicy.onFailure(
        delay: Duration(milliseconds: 10),
        maxBurst: 2,
      ),
      logSink: (_) {},
      startProcess: (exe, args, {workingDirectory, environment, includeParentEnvironment = true, runInShell = false}) async {
        starts += 1;
        return _FakeProcess(exitAfter: const Duration(milliseconds: 5));
      },
    );

    await sup.start(executable: '/bin/x');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(starts, lessThanOrEqualTo(3));
    await sup.stop();
  });
}
