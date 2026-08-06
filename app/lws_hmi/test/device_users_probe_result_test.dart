import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/device_users_client.dart';

void main() {
  group('DeviceUsersProbeResult.needsRegistration', () {
    test('bare HTTP 401 without INVALID_SN is not registration', () {
      const r = DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        statusCode: 401,
        error: 'HTTP 401',
      );
      expect(r.needsRegistration, isFalse);
      expect(r.unbound, isFalse);
    });

    test('INVALID_SN errorCode', () {
      const r = DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        statusCode: 401,
        errorCode: 'INVALID_SN',
        rawBody:
            '{"code":401,"errorCode":"INVALID_SN","message":"Invalid device serial number"}',
      );
      expect(r.needsRegistration, isTrue);
    });

    test('invalid_sn in body requires registration', () {
      const r = DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        statusCode: 401,
        rawBody: 'invalid_sn',
      );
      expect(r.needsRegistration, isTrue);
    });

    test('empty users is unbound not registration', () {
      const r = DeviceUsersProbeResult(ok: true, userCount: 0, statusCode: 200);
      expect(r.unbound, isTrue);
      expect(r.needsRegistration, isFalse);
    });

    test('network failure is not registration', () {
      const r = DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        error: 'SocketException: Failed host lookup',
      );
      expect(r.needsRegistration, isFalse);
    });
  });
}
