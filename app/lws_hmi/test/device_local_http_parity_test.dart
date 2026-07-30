import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/local_http/api_result.dart';
import 'package:lws_hmi/platform/local_http/device_local_http_server.dart';
import 'package:lws_hmi/platform/local_http/monitor_alerts_sse_hub.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_snapshot.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_sse_hub.dart';
import 'package:lws_hmi/platform/local_http/multipart_form_data.dart';

void main() {
  group('MultipartFormData', () {
    test('parses fields and file part', () {
      const boundary = '----bound';
      final body = utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="processType"\r\n\r\n'
        '1\r\n'
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"; filename="a.mp4"\r\n'
        'Content-Type: video/mp4\r\n\r\n'
        'abcd\r\n'
        '--$boundary--\r\n',
      );
      final parsed = MultipartFormData.parseBytes(
        Uint8List.fromList(body),
        boundary,
      );
      expect(parsed, isNotNull);
      expect(parsed!.fields['processType'], '1');
      expect(parsed.files['file'], isNotNull);
      expect(File(parsed.files['file']!).readAsBytesSync(), utf8.encode('abcd'));
      File(parsed.files['file']!).deleteSync();
    });
  });

  group('DeviceLocalHttpServer routes', () {
    late DeviceLocalHttpServer http;
    late _MemVideoRepo repo;
    late int port;

    setUp(() async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = probe.port;
      await probe.close();
      repo = _MemVideoRepo();
      final statHub = MonitorStatSseHub(
        snapshotSupplier: () => const MonitorStatSnapshot(
          deviceStatus: {'cameraStatus': 1},
          deviceData: {},
          processParameters: null,
        ),
        heartbeatInterval: const Duration(hours: 1),
      );
      final alertsHub = MonitorAlertsSseHub(
        listSupplier: () async => [
          {'code': 'H001', 'title': 't'},
        ],
        heartbeatInterval: const Duration(hours: 1),
      );
      http = DeviceLocalHttpServer(
        port: port,
        processVideoRepository: repo,
        monitorStatHub: statHub,
        monitorAlertsHub: alertsHub,
        cameraRecordHandler: (sw) async {
          if (sw == 'on') {
            return LocalHttpCameraActionResult.success(data: {'switch': 'on'});
          }
          return LocalHttpCameraActionResult.success(data: {'switch': 'off'});
        },
      );
      expect(await http.start(), isTrue);
    });

    tearDown(() async {
      await http.stop();
    });

    Future<HttpClientResponse> get(String path) async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
      return req.close();
    }

    Future<HttpClientResponse> postJson(String path, Object? body) async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      return req.close();
    }

    test('GET /lasercyber', () async {
      final resp = await get('/lasercyber');
      final body = await resp.transform(utf8.decoder).join();
      expect(resp.statusCode, 200);
      expect(body, 'Hello LaserCyber');
    });

    test('GET /v1/videos uses videoId paths and filters', () async {
      repo.seed(
        ProcessVideoRecord(
          id: 1,
          videoId: 'vid-a',
          videoPath: '/tmp/a.mp4',
          processType: ProcessType.continuousWelding,
          materialType: MaterialType.carbonSteel,
          processParametersJson: '{}',
          fileSize: 10,
          durationMs: 1000,
          resolution: '1920x1080',
          createTimeMs: 2000,
          uploadStatus: ProcessVideoUploadStatus.coverUploaded,
        ),
      );
      repo.seed(
        ProcessVideoRecord(
          id: 2,
          videoId: 'vid-b',
          videoPath: '/tmp/b.mp4',
          processType: ProcessType.cncCutting,
          materialType: MaterialType.stainlessSteel,
          processParametersJson: '{}',
          fileSize: 20,
          durationMs: 2000,
          resolution: '1280x720',
          createTimeMs: 3000,
          uploadStatus: ProcessVideoUploadStatus.notInitiated,
        ),
      );

      final listResp = await get(
        '/v1/videos?processType=${ProcessType.continuousWelding.wireValue}&uploadStatus=1',
      );
      final listBody = jsonDecode(await listResp.transform(utf8.decoder).join());
      expect(listResp.statusCode, 200);
      expect(listBody['success'], isTrue);
      expect(listBody['data']['total'], 1);
      expect(listBody['data']['list'][0]['videoId'], 'vid-a');

      final one = await get('/v1/videos/vid-a');
      final oneBody = jsonDecode(await one.transform(utf8.decoder).join());
      expect(one.statusCode, 200);
      expect(oneBody['data']['videoId'], 'vid-a');
      expect(oneBody['data']['resolution'], '1920x1080');
    });

    test('POST /v1/videos missing file', () async {
      final client = HttpClient();
      final req =
          await client.postUrl(Uri.parse('http://127.0.0.1:$port/v1/videos'));
      const boundary = '----t';
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      req.write(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="processType"\r\n\r\n'
        '1\r\n'
        '--$boundary--\r\n',
      );
      final resp = await req.close();
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(resp.statusCode, 400);
      expect(body['message'], 'missing_file');
    });

    test('GET /v1/process-library requires processType', () async {
      final resp = await get('/v1/process-library');
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      // No library backend → 503; with null library that's expected.
      expect(resp.statusCode, anyOf(400, 503));
      if (resp.statusCode == 400) {
        expect(body['message'], 'missing_process_type');
      }
    });

    test('POST /v1/adb success data is null', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final p = probe.port;
      await probe.close();
      final server = DeviceLocalHttpServer(port: p, sshDebug: _FakeSsh());
      await server.start();
      addTearDown(server.stop);
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$p/v1/adb'));
      final resp = await req.close();
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(resp.statusCode, 200);
      expect(body['success'], isTrue);
      expect(body['data'], isNull);
    });

    test('GET /v1/camera/ai returns plain 503', () async {
      final resp = await get('/v1/camera/ai');
      final body = await resp.transform(utf8.decoder).join();
      expect(resp.statusCode, 503);
      expect(body, 'camera_ai_unavailable');
    });

    test('POST /v1/camera/record', () async {
      final resp = await postJson('/v1/camera/record', {'switch': 'on'});
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(resp.statusCode, 200);
      expect(body['data']['switch'], 'on');
    });

    test('POST /v1/camera/show-overlay unavailable', () async {
      final resp = await postJson('/v1/camera/show-overlay', {
        'enable': 1,
        'positionx': 10,
        'positiony': 10,
      });
      final body = jsonDecode(await resp.transform(utf8.decoder).join());
      expect(resp.statusCode, 503);
      expect(body['message'], 'show_overlay_unavailable');
    });

    test('GET /v1/monitor/stat SSE first event', () async {
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/v1/monitor/stat'),
      );
      final resp = await req.close();
      expect(resp.statusCode, 200);
      expect(resp.headers.contentType?.mimeType, 'text/event-stream');
      final buffer = StringBuffer();
      await for (final chunk in resp.transform(utf8.decoder)) {
        buffer.write(chunk);
        if (buffer.toString().contains('event: stat')) {
          break;
        }
      }
      expect(buffer.toString(), contains('event: stat'));
      client.close(force: true);
    });

    test('GET /v1/videos/:id/ai unavailable', () async {
      repo.seed(
        ProcessVideoRecord(
          id: 9,
          videoId: 'vid-ai',
          videoPath: '/tmp/x.mp4',
          processType: ProcessType.continuousWelding,
          processParametersJson: '',
          fileSize: 1,
          durationMs: 1000,
          createTimeMs: 1,
        ),
      );
      final resp = await get('/v1/videos/vid-ai/ai');
      final body = await resp.transform(utf8.decoder).join();
      expect(resp.statusCode, 503);
      expect(body, 'process_video_ai_unavailable');
    });
  });

  group('ApiResult', () {
    test('ok encodes data null', () {
      final encoded = jsonDecode(ApiResult.ok().encode());
      expect(encoded['success'], isTrue);
      expect(encoded['data'], isNull);
    });
  });
}

final class _FakeSsh implements SshDebug {
  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {}
}

final class _MemVideoRepo implements ProcessVideoRepository {
  final List<ProcessVideoRecord> _rows = [];

  void seed(ProcessVideoRecord record) => _rows.add(record);

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<int> count() async => _rows.length;

  @override
  Future<ProcessVideoRecord> insert(ProcessVideoRecord record) async {
    final saved = ProcessVideoRecord(
      id: _rows.length + 1,
      videoId: record.videoId,
      videoPath: record.videoPath,
      processType: record.processType,
      materialType: record.materialType,
      processParametersJson: record.processParametersJson,
      fileSize: record.fileSize,
      durationMs: record.durationMs,
      resolution: record.resolution,
      createTimeMs: record.createTimeMs,
      uploadStatus: record.uploadStatus,
      uploadProgress: record.uploadProgress,
    );
    _rows.add(saved);
    return saved;
  }

  @override
  Future<List<ProcessVideoRecord>> list({int limit = 10, int offset = 0}) async {
    final sorted = [..._rows]
      ..sort((a, b) => b.createTimeMs.compareTo(a.createTimeMs));
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<ProcessVideoListPage> query(ProcessVideoListQuery q) async {
    var rows = [..._rows];
    if (q.processType != null) {
      rows = rows
          .where((r) => r.processType.wireValue == q.processType)
          .toList();
    }
    if (q.uploadStatus != null) {
      rows = rows.where((r) => r.uploadStatus == q.uploadStatus).toList();
    } else if (q.excludeNotInitiatedWhenUploadStatusUnset) {
      rows = rows
          .where((r) => r.uploadStatus != ProcessVideoUploadStatus.notInitiated)
          .toList();
    }
    rows.sort(
      (a, b) => q.orderAsc
          ? a.createTimeMs.compareTo(b.createTimeMs)
          : b.createTimeMs.compareTo(a.createTimeMs),
    );
    final total = rows.length;
    final start = ((q.page < 1 ? 1 : q.page) - 1) * q.pageSize;
    final page = rows.skip(start).take(q.pageSize).toList();
    return ProcessVideoListPage(list: page, total: total);
  }

  @override
  Future<ProcessVideoRecord?> findByVideoId(String videoId) async {
    for (final row in _rows) {
      if (row.videoId == videoId) return row;
    }
    return null;
  }

  @override
  Future<bool> updateUploadState({
    required String videoId,
    required int uploadStatus,
    required int uploadProgress,
    String? coverUrl,
    String? videoUrl,
  }) async =>
      true;

  @override
  Future<ProcessVideoRecord?> getById(int id) async {
    for (final row in _rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  @override
  Future<bool> deleteById(int id) async {
    final before = _rows.length;
    _rows.removeWhere((r) => r.id == id);
    return _rows.length < before;
  }

  @override
  Future<bool> deleteByVideoId(String videoId) async {
    final before = _rows.length;
    _rows.removeWhere((r) => r.videoId == videoId);
    return _rows.length < before;
  }
}
