import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_store.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/device_ws_envelope.dart';
import 'package:lws_hmi/platform/local_http/api_result.dart';
import 'package:lws_hmi/platform/local_http/device_local_http_server.dart';

void main() {
  group('DeviceApiOriginConfig', () {
    test('maps https pin to wss device URL with sn', () {
      final uri = DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: Uri.parse('https://api-test.lasercyber.workers.dev'),
        deviceSn: 'ABC123',
      );
      expect(uri.scheme, 'wss');
      expect(uri.host, 'api-test.lasercyber.workers.dev');
      expect(uri.path, '/ws/device');
      expect(uri.queryParameters['sn'], 'ABC123');
    });

    test('maps http pin with path prefix to ws', () {
      final uri = DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: Uri.parse('http://47.86.53.176:8080/prod'),
        deviceSn: 'SN1',
      );
      expect(uri.scheme, 'ws');
      expect(uri.path, '/prod/ws/device');
      expect(uri.queryParameters['sn'], 'SN1');
    });

    test('ordered candidates differ by tier', () {
      final test = DeviceApiOriginConfig.orderedCandidateBases(
        CloudEnvironmentTier.test,
      );
      final prod = DeviceApiOriginConfig.orderedCandidateBases(
        CloudEnvironmentTier.prod,
      );
      expect(test.first.toString(), contains('api-test'));
      expect(prod.first.toString(), contains('api-prod'));
    });
  });

  group('DeviceWsEnvelope', () {
    test('round-trips JSON', () {
      final env = DeviceWsEnvelope.build(
        type: 'command.lock',
        id: 'id-1',
        payload: {'x': 1},
      );
      final parsed = DeviceWsEnvelope.tryParse(env.encode());
      expect(parsed, isNotNull);
      expect(parsed!.type, 'command.lock');
      expect(parsed.id, 'id-1');
      expect(parsed.isOtaRelated, isFalse);
    });

    test('classifies OTA types', () {
      expect(
        DeviceWsEnvelope.build(type: 'command.check_update').isOtaRelated,
        isTrue,
      );
      expect(
        DeviceWsEnvelope.build(type: 'command.update_system').isOtaRelated,
        isTrue,
      );
    });

    test('malformed returns null', () {
      expect(DeviceWsEnvelope.tryParse('not-json'), isNull);
      expect(DeviceWsEnvelope.tryParse('{}'), isNull);
    });
  });

  group('DeviceRemoteLockStore', () {
    test('persists lock flag', () async {
      final dir = await Directory.systemTemp.createTemp('remote-lock-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/remote-lock.json';
      final a = DeviceRemoteLockStore(preferencePath: path)..warmRead();
      expect(a.isLocked, isFalse);
      await a.setLocked(true);
      final b = DeviceRemoteLockStore(preferencePath: path)..warmRead();
      expect(b.isLocked, isTrue);
    });
  });

  group('CloudSettingsStore', () {
    test('persists environment tier', () async {
      final dir = await Directory.systemTemp.createTemp('cloud-settings-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/cloud-settings.json';
      final a = CloudSettingsStore(preferencePath: path)..warmRead();
      await a.setEnvironmentTier(CloudEnvironmentTier.prod);
      final b = CloudSettingsStore(preferencePath: path)..warmRead();
      expect(b.environmentTier, CloudEnvironmentTier.prod);
    });
  });

  group('DeviceLocalHttpServer', () {
    test('GET /lasercyber returns Hello LaserCyber', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final http = DeviceLocalHttpServer(port: port);
      final ok = await http.start();
      expect(ok, isTrue);
      addTearDown(http.stop);

      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/lasercyber'),
      );
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      expect(resp.statusCode, 200);
      expect(body, 'Hello LaserCyber');
      client.close(force: true);
    });

    test('ApiResult encodes success', () {
      final json = ApiResult.ok(data: {'a': 1}).encode();
      expect(json, contains('"success":true'));
      expect(json, contains('"a":1'));
    });
  });
}
