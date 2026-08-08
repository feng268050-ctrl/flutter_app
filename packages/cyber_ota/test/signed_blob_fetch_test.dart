import 'dart:io';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:test/test.dart';

final class _FakeVerify extends OtaVerify {
  _FakeVerify() : super(processRunner: ProcessRunner());

  int calls = 0;
  Object? error;

  @override
  Future<void> verifyPackage({
    required String archivePath,
    required String sigPath,
  }) async {
    calls++;
    final err = error;
    if (err != null) {
      throw err;
    }
  }
}

void main() {
  late Directory tmp;
  late FakeOtaHttpClient http;
  late _FakeVerify verify;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('signed-blob-fetch-');
    http = FakeOtaHttpClient();
    verify = _FakeVerify();
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('downloadAndVerify fetches package + .sig then verifies', () async {
    final fetch = SignedBlobFetch(httpClient: http, verify: verify);
    final file = await fetch.downloadAndVerify(
      packageUrl: 'http://host/LSW01H1000S1017.bin',
      stagingDir: tmp.path,
      fileName: 'LSW01H1000S1017.bin',
    );

    expect(file.path, endsWith('LSW01H1000S1017.bin'));
    expect(await file.exists(), isTrue);
    expect(http.downloads, [
      'http://host/LSW01H1000S1017.bin',
      'http://host/LSW01H1000S1017.bin.sig',
    ]);
    expect(verify.calls, 1);
    expect(await File('${file.path}.sig').exists(), isTrue);
  });

  test('downloadAndVerify refuses when verify fails', () async {
    verify.error = StateError('bad sig');
    final fetch = SignedBlobFetch(httpClient: http, verify: verify);

    await expectLater(
      () => fetch.downloadAndVerify(
        packageUrl: 'http://host/cam.zip',
        stagingDir: '${tmp.path}/camera',
        fileName: 'cam.zip',
      ),
      throwsA(isA<StateError>()),
    );
    expect(verify.calls, 1);
  });

  test('staging constants live under /userdata/ota/', () {
    expect(kControlBoardStagingDir, '/userdata/ota/control-board/');
    expect(kCameraStagingDir, '/userdata/ota/camera/');
  });
}
