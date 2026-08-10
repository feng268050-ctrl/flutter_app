import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_applicator.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';

final class _FakeCameraHttpClient implements CameraOsdHttpClient {
  _FakeCameraHttpClient({
    this.upgradeStatus = 200,
    this.rebootStatus = 200,
  });

  int upgradeStatus;
  int rebootStatus;
  final calls = <String>[];

  @override
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  }) async {
    calls.add('GET ${uri.path}');
    return const CameraOsdHttpResponse(statusCode: 200, body: '{}');
  }

  @override
  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  }) async {
    calls.add('PUT ${uri.path}');
    return CameraOsdHttpResponse(statusCode: rebootStatus, body: '{}');
  }

  @override
  Future<CameraOsdHttpResponse> postMultipartFile(
    Uri uri, {
    required String authorization,
    required String fieldName,
    required String fileName,
    required List<int> fileBytes,
    String fileContentType = 'application/octet-stream',
    void Function(int sent, int total)? onSendProgress,
  }) async {
    calls.add('POST ${uri.path} field=$fieldName file=$fileName');
    onSendProgress?.call(fileBytes.length, fileBytes.length);
    return CameraOsdHttpResponse(statusCode: upgradeStatus, body: 'ok');
  }

  @override
  void close() {}
}

final class _CapturingHttp implements CameraOsdHttpClient {
  _CapturingHttp(this._inner, {this.onPost});

  final CameraOsdHttpClient _inner;
  final void Function(Uri uri)? onPost;

  @override
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  }) =>
      _inner.get(uri, authorization: authorization);

  @override
  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  }) =>
      _inner.put(uri, authorization: authorization, body: body);

  @override
  Future<CameraOsdHttpResponse> postMultipartFile(
    Uri uri, {
    required String authorization,
    required String fieldName,
    required String fileName,
    required List<int> fileBytes,
    String fileContentType = 'application/octet-stream',
    void Function(int sent, int total)? onSendProgress,
  }) {
    onPost?.call(uri);
    return _inner.postMultipartFile(
      uri,
      authorization: authorization,
      fieldName: fieldName,
      fileName: fileName,
      fileBytes: fileBytes,
      fileContentType: fileContentType,
      onSendProgress: onSendProgress,
    );
  }

  @override
  void close() => _inner.close();
}

void main() {
  group('CameraProgramUpgradeApplicator', () {
    test('success: CGI 200 → reboot 200 → wait online', () async {
      final http = _FakeCameraHttpClient();
      var attempts = 0;
      final applicator = CameraProgramUpgradeApplicator(
        httpClient: http,
        probeOnline: (_) async {
          attempts++;
          return attempts >= 1 ? 'v1.0.7 build20260513' : null;
        },
        waitOnlineTimeout: const Duration(seconds: 5),
        waitOnlinePollInterval: const Duration(milliseconds: 10),
        initialOfflineGrace: Duration.zero,
      );
      addTearDown(applicator.dispose);
      final phases = <CameraProgramUpgradePhase>[];
      final result = await applicator.upgrade(
        cameraHost: '192.168.1.10',
        fileName: 'LTC609-v1.0.7 build20260513.zip',
        bytes: Uint8List.fromList([1, 2, 3]),
        onProgress: (phase, _) => phases.add(phase),
      );
      expect(result.isSuccess, isTrue);
      expect(http.calls, [
        'POST /cgi-bin/cgic_upgrade field=file file=LTC609-v1.0.7 build20260513.zip',
        'PUT /System/reboot',
      ]);
      expect(phases, contains(CameraProgramUpgradePhase.transfer));
      expect(phases, contains(CameraProgramUpgradePhase.reboot));
      expect(phases, contains(CameraProgramUpgradePhase.waitOnline));
    });

    test('CGI upload uses webServerPort 80 by default', () async {
      final http = _FakeCameraHttpClient();
      Uri? seen;
      final wrapped = _CapturingHttp(http, onPost: (uri) => seen = uri);
      final applicator = CameraProgramUpgradeApplicator(
        httpClient: wrapped,
        probeOnline: (_) async => 'v1.0.7 build20260513',
        waitOnlineTimeout: const Duration(seconds: 5),
        waitOnlinePollInterval: const Duration(milliseconds: 10),
        initialOfflineGrace: Duration.zero,
      );
      addTearDown(applicator.dispose);
      await applicator.upgrade(
        cameraHost: '192.168.1.10',
        fileName: 'fw.zip',
        bytes: Uint8List.fromList([1]),
      );
      expect(seen?.port, 80);
      expect(seen?.path, '/cgi-bin/cgic_upgrade');
    });

    test('CGI non-200 fails transfer', () async {
      final http = _FakeCameraHttpClient(upgradeStatus: 500);
      final applicator = CameraProgramUpgradeApplicator(
        httpClient: http,
        probeOnline: (_) async => 'v1.0.7 build20260513',
        initialOfflineGrace: Duration.zero,
      );
      addTearDown(applicator.dispose);
      final result = await applicator.upgrade(
        cameraHost: '192.168.1.10',
        fileName: 'fw.zip',
        bytes: Uint8List.fromList([1]),
      );
      expect(result.outcome, CameraProgramUpgradeOutcome.transferFailed);
      expect(http.calls.length, 1);
    });

    test('reboot non-200 fails reboot phase', () async {
      final http = _FakeCameraHttpClient(rebootStatus: 503);
      final applicator = CameraProgramUpgradeApplicator(
        httpClient: http,
        probeOnline: (_) async => 'v1.0.7 build20260513',
        initialOfflineGrace: Duration.zero,
      );
      addTearDown(applicator.dispose);
      final result = await applicator.upgrade(
        cameraHost: '192.168.1.10',
        fileName: 'fw.zip',
        bytes: Uint8List.fromList([1]),
      );
      expect(result.outcome, CameraProgramUpgradeOutcome.rebootFailed);
      expect(http.calls.length, 2);
    });

    test('wait timeout fails even after CGI+reboot 200', () async {
      final http = _FakeCameraHttpClient();
      final applicator = CameraProgramUpgradeApplicator(
        httpClient: http,
        probeOnline: (_) async => null,
        waitOnlineTimeout: const Duration(milliseconds: 50),
        waitOnlinePollInterval: const Duration(milliseconds: 10),
        initialOfflineGrace: Duration.zero,
      );
      addTearDown(applicator.dispose);
      final result = await applicator.upgrade(
        cameraHost: '192.168.1.10',
        fileName: 'fw.zip',
        bytes: Uint8List.fromList([1]),
      );
      expect(result.outcome, CameraProgramUpgradeOutcome.waitTimeout);
    });
  });

  group('DartCameraOsdHttpClient multipart + empty PUT', () {
    test('POST multipart and empty PUT Content-Length 0', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final seen = <Map<String, Object?>>[];
      final done = Completer<void>();
      server.listen((request) async {
        final headers = <String, String>{};
        request.headers.forEach((name, values) {
          headers[name.toLowerCase()] = values.join(',');
        });
        final body = await utf8.decoder.bind(request).join();
        seen.add(<String, Object?>{
          'method': request.method,
          'path': request.uri.path,
          'headers': headers,
          'body': body,
        });
        request.response.statusCode = 200;
        request.response.write('ok');
        await request.response.close();
        if (seen.length >= 2 && !done.isCompleted) {
          done.complete();
        }
      });

      final client = DartCameraOsdHttpClient();
      addTearDown(client.close);
      final uriBase = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: server.port,
      );
      await client.postMultipartFile(
        uriBase.replace(path: '/cgi-bin/cgic_upgrade'),
        authorization: 'Basic dGVzdA==',
        fieldName: 'file',
        fileName: 'fw.zip',
        fileBytes: utf8.encode('ZIPDATA'),
      );
      await client.put(
        uriBase.replace(path: '/System/reboot'),
        authorization: 'Basic dGVzdA==',
      );
      await done.future.timeout(const Duration(seconds: 2));

      expect(seen.length, 2);
      final post = seen[0];
      expect(post['method'], 'POST');
      expect(post['path'], '/cgi-bin/cgic_upgrade');
      final postHeaders = post['headers']! as Map<String, String>;
      expect(postHeaders['content-type'], contains('multipart/form-data'));
      expect(postHeaders['authorization'], 'Basic dGVzdA==');
      expect(post['body'] as String, contains('name="file"'));
      expect(post['body'] as String, contains('ZIPDATA'));

      final put = seen[1];
      expect(put['method'], 'PUT');
      expect(put['path'], '/System/reboot');
      final putHeaders = put['headers']! as Map<String, String>;
      expect(putHeaders['content-length'], '0');
      expect(put['body'], '');
    });
  });
}
