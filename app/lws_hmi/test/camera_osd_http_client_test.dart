import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_overlay_applier.dart';

void main() {
  group('DartCameraOsdHttpClient', () {
    test('PUT sends Content-Length body, not chunked', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final seen = Completer<Map<String, Object?>>();
      server.listen((request) async {
        final headers = <String, String>{};
        request.headers.forEach((name, values) {
          headers[name.toLowerCase()] = values.join(',');
        });
        final body = await utf8.decoder.bind(request).join();
        if (!seen.isCompleted) {
          seen.complete(<String, Object?>{
            'method': request.method,
            'path': request.uri.path,
            'headers': headers,
            'body': body,
          });
        }
        request.response.statusCode = 200;
        request.response.write('{"errCode":200}');
        await request.response.close();
      });

      final client = DartCameraOsdHttpClient();
      addTearDown(client.close);
      final res = await client.put(
        Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: server.port,
          path: '/System/showtime',
        ),
        authorization: 'Basic dGVzdA==',
        body: <String, Object?>{'enable': 1, 'positionx': 10},
      );
      expect(res.statusCode, 200);

      final got = await seen.future.timeout(const Duration(seconds: 2));
      expect(got['method'], 'PUT');
      expect(got['path'], '/System/showtime');
      final headers = got['headers']! as Map<String, String>;
      expect(headers.containsKey('content-length'), isTrue);
      expect(headers['transfer-encoding'], isNull);
      expect(headers['content-type'], 'application/json');
      expect(headers['authorization'], 'Basic dGVzdA==');
      final body = got['body']! as String;
      expect(jsonDecode(body), {
        'enable': 1,
        'positionx': 10,
      });
      expect(headers['content-length'], '${utf8.encode(body).length}');
    });
  });
}
