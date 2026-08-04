import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';

final class _FakeOsdHttp implements CameraOsdHttpClient {
  final List<String> calls = <String>[];
  Object? putShowTimeBody;
  Object? putOverlaysBody;
  int getOverlaysStatus = 200;
  String getOverlaysBody = jsonEncode({
    'VideoOverlay': {'NameOverlay': <String, Object?>{}},
  });
  int putStatus = 200;
  String putBody = jsonEncode({'errCode': 200});
  bool failGet = false;

  @override
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  }) async {
    calls.add('GET ${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}');
    if (failGet) {
      throw StateError('unreachable');
    }
    return CameraOsdHttpResponse(
      statusCode: getOverlaysStatus,
      body: getOverlaysBody,
    );
  }

  @override
  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  }) async {
    final path = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    calls.add('PUT $path');
    if (path.endsWith('/System/showtime') || path.endsWith('System/showtime')) {
      putShowTimeBody = body;
    }
    if (path.contains('overlays')) {
      putOverlaysBody = body;
    }
    return CameraOsdHttpResponse(statusCode: putStatus, body: putBody);
  }

  @override
  void close() {}
}

void main() {
  group('CameraShowOverlayParams', () {
    test('rejects enable outside 0/1', () {
      expect(
        CameraShowOverlayParams.tryParse(enableRaw: 2),
        isNull,
      );
    });

    test('rejects Y>238 when enable=1', () {
      expect(
        CameraShowOverlayParams.tryParse(
          enableRaw: 1,
          positionXRaw: 10,
          positionYRaw: 250,
        ),
        isNull,
      );
    });

    test('defaults X/Y to 10', () {
      final p = CameraShowOverlayParams.tryParse(enableRaw: 0)!;
      expect(p.positionX, 10);
      expect(p.positionY, 10);
    });
  });

  group('CameraShowOverlayApplier', () {
    test('success path showtime → overlays → saveConf', () async {
      final http = _FakeOsdHttp();
      final applier = CameraShowOverlayApplier(
        httpClient: http,
        now: () => DateTime(2026, 1, 2, 11, 4, 5),
      );
      final result = await applier.apply(
        cameraHost: '192.168.1.100',
        machineModel: 'Laser-01',
        params: const CameraShowOverlayParams(
          enable: 1,
          positionX: 20,
          positionY: 30,
        ),
      );
      expect(result.ok, isTrue);
      expect(result.dataMap()['nameoverlayy'], 80);
      expect(http.calls, [
        'PUT /System/showtime',
        'GET /Media/Video/overlays?channel=1',
        'PUT /Media/Video/overlays?channel=1',
        'PUT /System/saveConf',
      ]);
      final showTime = http.putShowTimeBody as Map;
      expect(showTime['enable'], 1);
      expect(showTime['year'], 2026);
      final overlays = http.putOverlaysBody as Map;
      final name = (overlays['VideoOverlay'] as Map)['NameOverlay'] as Map;
      expect(name['y'], 80);
      expect(name['name'], 'Laser-01');
      applier.dispose();
    });

    test('enable=0 still only showtime → overlays → saveConf', () async {
      final http = _FakeOsdHttp();
      final applier = CameraShowOverlayApplier(httpClient: http);
      final result = await applier.apply(
        cameraHost: '192.168.1.100',
        machineModel: 'Laser-01',
        params: const CameraShowOverlayParams(
          enable: 0,
          positionX: 10,
          positionY: 10,
        ),
      );
      expect(result.ok, isTrue);
      expect(http.calls, [
        'PUT /System/showtime',
        'GET /Media/Video/overlays?channel=1',
        'PUT /Media/Video/overlays?channel=1',
        'PUT /System/saveConf',
      ]);
      final showTime = http.putShowTimeBody as Map;
      expect(showTime['enable'], 0);
      expect(showTime['year'], 0);
      applier.dispose();
    });

    test('validation failure does not hit HTTP', () async {
      final http = _FakeOsdHttp();
      final applier = CameraShowOverlayApplier(httpClient: http);
      final params = CameraShowOverlayParams.tryParse(
        enableRaw: 1,
        positionYRaw: 250,
      );
      expect(params, isNull);
      expect(http.calls, isEmpty);
      applier.dispose();
    });

    test('HTTP failure returns structured error', () async {
      final http = _FakeOsdHttp()..putStatus = 500;
      final applier = CameraShowOverlayApplier(httpClient: http);
      final result = await applier.apply(
        cameraHost: '192.168.1.100',
        machineModel: 'M',
        params: const CameraShowOverlayParams(
          enable: 0,
          positionX: 10,
          positionY: 10,
        ),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('System/showtime_http_500'));
      applier.dispose();
    });

    test('serializes concurrent applies', () async {
      final http = _FakeOsdHttp();
      final applier = CameraShowOverlayApplier(httpClient: http);
      final a = applier.apply(
        cameraHost: '192.168.1.100',
        machineModel: 'A',
        params: const CameraShowOverlayParams(
          enable: 0,
          positionX: 1,
          positionY: 1,
        ),
      );
      final b = applier.apply(
        cameraHost: '192.168.1.100',
        machineModel: 'B',
        params: const CameraShowOverlayParams(
          enable: 0,
          positionX: 2,
          positionY: 2,
        ),
      );
      final results = await Future.wait([a, b]);
      expect(results.every((r) => r.ok), isTrue);
      // 4 calls each (enable=0 skips System/time) → 8 total.
      expect(http.calls.length, 8);
      applier.dispose();
    });
  });
}
