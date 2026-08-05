import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

void main() {
  test('DdWriter copies exact bytes with monotonic progress', () async {
    final dir = await Directory.systemTemp.createTemp('dd-writer-');
    final img = File('${dir.path}/rootfs.img');
    final dest = File('${dir.path}/dest.img');
    const total = 3 * 1024 * 1024 + 123;
    final payload = Uint8List(total);
    for (var i = 0; i < total; i++) {
      payload[i] = i & 0xff;
    }
    await img.writeAsBytes(payload);

    final progress = <(int, int)>[];
    final writer = DdWriter(blockSize: 4 * 1024 * 1024);
    await writer.writeImage(
      imagePath: img.path,
      devicePath: dest.path,
      onProgress: (w, t) => progress.add((w, t)),
    );

    expect(await dest.length(), total);
    expect(await dest.readAsBytes(), payload);
    expect(progress.first.$1, 0);
    expect(progress.last.$1, total);
    expect(progress.last.$2, total);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
    }

    await dir.delete(recursive: true);
  });

  test('DdWriter streams /dev target via dd stdin with byte progress', () async {
    final dir = await Directory.systemTemp.createTemp('dd-writer-dev-');
    final img = File('${dir.path}/rootfs.img');
    const total = 512 * 1024 + 17;
    final payload = Uint8List(total);
    for (var i = 0; i < total; i++) {
      payload[i] = (i * 3) & 0xff;
    }
    await img.writeAsBytes(payload);

    final received = BytesBuilder(copy: false);
    late _FakeDdProcess fake;
    final runner = ProcessRunner(
      startProcess: (
        executable,
        arguments, {
        Map<String, String>? environment,
        bool includeParentEnvironment = true,
        bool runInShell = false,
      }) async {
        if (executable == 'sync') {
          return _FakeSyncProcess();
        }
        expect(executable, 'dd');
        expect(arguments, contains('of=/dev/mmcblk0p7'));
        expect(arguments.any((a) => a.startsWith('if=')), isFalse);
        fake = _FakeDdProcess(onBytes: received.add);
        return fake;
      },
    );

    final progress = <(int, int)>[];
    final writer = DdWriter(processRunner: runner);
    await writer.writeImage(
      imagePath: img.path,
      devicePath: '/dev/mmcblk0p7',
      onProgress: (w, t) => progress.add((w, t)),
    );

    expect(received.toBytes(), payload);
    expect(fake.stdinClosed, isTrue);
    expect(progress.first.$1, 0);
    expect(progress.last.$1, total);
    expect(progress.any((e) => e.$1 > 0 && e.$1 < total), isTrue);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i].$1, greaterThanOrEqualTo(progress[i - 1].$1));
    }

    await dir.delete(recursive: true);
  });
}

final class _FakeDdProcess implements Process {
  _FakeDdProcess({required this.onBytes}) {
    _stdin = _RecordingSink(
      onBytes: onBytes,
      onClose: () {
        _stdinClosed = true;
        if (!_exit.isCompleted) {
          _exit.complete(0);
        }
      },
    );
  }

  final void Function(List<int> bytes) onBytes;
  final Completer<int> _exit = Completer<int>();
  late final _RecordingSink _stdin;
  var _stdinClosed = false;

  bool get stdinClosed => _stdinClosed;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) {
      _exit.complete(-1);
    }
    return true;
  }
}

final class _FakeSyncProcess implements Process {
  _FakeSyncProcess() {
    scheduleMicrotask(() => _exit.complete(0));
  }

  final Completer<int> _exit = Completer<int>();

  @override
  int get pid => 2;

  @override
  IOSink get stdin => _ClosedSink();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

final class _RecordingSink implements IOSink {
  _RecordingSink({required this.onBytes, required this.onClose});

  final void Function(List<int> bytes) onBytes;
  final void Function() onClose;
  final Completer<void> _done = Completer<void>();

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => onBytes(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      onBytes(chunk);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    onClose();
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}
}

final class _ClosedSink implements IOSink {
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}
}
