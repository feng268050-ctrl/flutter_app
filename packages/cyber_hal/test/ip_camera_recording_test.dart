import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/ip_camera.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StubIpCameraRecordingController', () {
    test('start stays preparing until markReady', () async {
      final recorder = StubIpCameraRecordingController();
      final phases = <IpCameraRecordingPhase>[];
      recorder.status.listen((s) => phases.add(s.phase));

      final future = recorder.start(IpCameraRecordingRequest(
        sourceCandidates: [Uri.parse('rtsp://127.0.0.1:8554/camera/pr0')],
        outputPath: '/tmp/demo.mp4',
      ));
      await pumpEventQueue();
      expect(recorder.currentStatus.phase, IpCameraRecordingPhase.preparing);

      recorder.markReady();
      final status = await future;
      expect(status.phase, IpCameraRecordingPhase.recording);
      expect(phases, contains(IpCameraRecordingPhase.preparing));
      expect(phases, contains(IpCameraRecordingPhase.recording));

      final result = await recorder.stop();
      expect(result, isNotNull);
      expect(result!.outputPath, '/tmp/demo.mp4');
      expect(result.bytesWritten, greaterThan(0));
      await recorder.dispose();
    });

    test('stop while preparing cancels without completed result', () async {
      final recorder = StubIpCameraRecordingController();
      final future = recorder.start(IpCameraRecordingRequest(
        sourceCandidates: [Uri.parse('rtsp://127.0.0.1/PR0')],
        outputPath: '/tmp/cancel.mp4',
      ));
      await pumpEventQueue();
      final result = await recorder.stop();
      expect(result, isNull);
      final status = await future;
      expect(status.phase, IpCameraRecordingPhase.failed);
      expect(status.detail, 'cancelled');
      await recorder.dispose();
    });

    test('autoReadyAfter transitions without UI polling', () async {
      final recorder = StubIpCameraRecordingController(
        autoReadyAfter: const Duration(milliseconds: 20),
      );
      final status = await recorder.start(IpCameraRecordingRequest(
        sourceCandidates: [Uri.parse('rtsp://127.0.0.1/PR0')],
        outputPath: '/tmp/auto.mp4',
      ));
      expect(status.phase, IpCameraRecordingPhase.recording);
      await recorder.dispose();
    });
  });

  group('LinuxIpCameraRecordingController', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ipcam-rec-');
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('waits for ASYNC_DONE before recording; stop returns path', () async {
      final out = '${tmp.path}/clip.mp4';
      final fake = _FakeGstProcess();
      final recorder = LinuxIpCameraRecordingController(
        processFactory: ({required arguments, environment}) async {
          expect(arguments, contains('-e'));
          expect(arguments.any((a) => a.contains('mp4mux')), isTrue);
          return fake;
        },
        minReadyBytes: 1 << 30, // readiness via bus message, not file size
      );

      final future = recorder.start(IpCameraRecordingRequest(
        sourceCandidates: [Uri.parse('rtsp://127.0.0.1:8554/camera/pr0')],
        outputPath: out,
        readyTimeout: const Duration(seconds: 5),
      ));
      await pumpEventQueue();
      expect(recorder.currentStatus.phase, IpCameraRecordingPhase.preparing);

      fake.emitStdout('Got message #5 from element pipeline0 (async-done): done');
      final status = await future.timeout(const Duration(seconds: 2));
      expect(status.phase, IpCameraRecordingPhase.recording);

      await File(out).writeAsBytes(List<int>.filled(2048, 1));
      final result = await recorder.stop();
      expect(result, isNotNull);
      expect(result!.outputPath, out);
      expect(result.bytesWritten, 2048);
      expect(fake.interrupted, isTrue);
      await recorder.dispose();
    });

    test('retries next candidate after early exit before ready', () async {
      final out = '${tmp.path}/retry.mp4';
      var spawnCount = 0;
      final first = _FakeGstProcess();
      final second = _FakeGstProcess();
      final recorder = LinuxIpCameraRecordingController(
        processFactory: ({required arguments, environment}) async {
          spawnCount++;
          return spawnCount == 1 ? first : second;
        },
        minReadyBytes: 1 << 30,
      );

      final future = recorder.start(IpCameraRecordingRequest(
        sourceCandidates: [
          Uri.parse('rtsp://127.0.0.1:8554/bad'),
          Uri.parse('rtsp://127.0.0.1:8554/camera/pr0'),
        ],
        outputPath: out,
        readyTimeout: const Duration(seconds: 5),
        retryDelay: const Duration(milliseconds: 10),
      ));
      await pumpEventQueue();
      first.exitWith(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await pumpEventQueue();
      expect(spawnCount, greaterThanOrEqualTo(2));

      second.emitStdout('async-done');
      final status = await future.timeout(const Duration(seconds: 2));
      expect(status.phase, IpCameraRecordingPhase.recording);
      await recorder.dispose();
    });

    test('two camera instances isolate recording state', () async {
      final aRec = StubIpCameraRecordingController();
      final bRec = StubIpCameraRecordingController();
      final a = StubIpCameraController(
        cameraHost: '10.0.0.1',
        recording: aRec,
      );
      final b = StubIpCameraController(
        cameraHost: '10.0.0.2',
        recording: bRec,
      );

      unawaited(a.recording.start(IpCameraRecordingRequest(
        sourceCandidates: [Uri.parse('rtsp://10.0.0.1/PR0')],
        outputPath: '/tmp/a.mp4',
      )));
      await pumpEventQueue();
      expect(a.recording.currentStatus.phase, IpCameraRecordingPhase.preparing);
      expect(b.recording.currentStatus.phase, IpCameraRecordingPhase.idle);

      await a.dispose();
      expect(b.recording.currentStatus.phase, IpCameraRecordingPhase.idle);
      await b.dispose();
    });
  });
}

class _FakeGstProcess implements IpCameraGstProcess {
  final _stdoutCtrl = StreamController<List<int>>.broadcast();
  final _stderrCtrl = StreamController<List<int>>.broadcast();
  final _exit = Completer<int>();
  bool interrupted = false;
  bool _running = true;

  @override
  Stream<List<int>> get stdout => _stdoutCtrl.stream;

  @override
  Stream<List<int>> get stderr => _stderrCtrl.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool get isRunning => _running;

  void emitStdout(String line) {
    _stdoutCtrl.add(utf8.encode('$line\n'));
  }

  void exitWith(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
    _running = false;
  }

  @override
  void interrupt() {
    interrupted = true;
    exitWith(0);
  }

  @override
  Future<void> kill() async {
    exitWith(9);
  }
}
