import 'dart:convert';

import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Bound cloud users for a device SN (`GET /v1/devices/:sn/users`).
final class DeviceUsersProbeResult {
  const DeviceUsersProbeResult({
    required this.ok,
    required this.userCount,
    this.error,
    this.rawBody,
  });

  final bool ok;
  final int userCount;
  final String? error;
  final String? rawBody;

  bool get unbound => ok && userCount == 0;
}

final class DeviceUsersClient {
  DeviceUsersClient({required this.cloudHttp});

  final CloudHttpClient cloudHttp;

  Future<DeviceUsersProbeResult> probeUsers({
    required Uri pinnedBase,
    required String deviceSn,
  }) async {
    final sn = deviceSn.trim();
    if (sn.isEmpty) {
      return const DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        error: 'empty sn',
      );
    }
    final url = DeviceApiOriginConfig.joinUnderBase(
      pinnedBase,
      '/v1/devices/${Uri.encodeComponent(sn)}/users',
    );
    final resp = await cloudHttp.getJson(url);
    if (!resp.ok) {
      return DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        error: resp.error ?? 'HTTP ${resp.statusCode}',
        rawBody: resp.body,
      );
    }
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        return DeviceUsersProbeResult(
          ok: false,
          userCount: 0,
          error: 'unexpected body',
          rawBody: resp.body,
        );
      }
      final map = Map<String, dynamic>.from(decoded);
      final code = map['code'];
      if (code is num && code.toInt() != 200) {
        return DeviceUsersProbeResult(
          ok: false,
          userCount: 0,
          error: map['msg']?.toString() ?? 'code $code',
          rawBody: resp.body,
        );
      }
      final data = map['data'];
      var count = 0;
      if (data is List) {
        count = data.length;
      } else if (data is Map) {
        final users = data['users'] ?? data['list'];
        if (users is List) {
          count = users.length;
        } else if (data['count'] is num) {
          count = (data['count'] as num).toInt();
        }
      }
      return DeviceUsersProbeResult(ok: true, userCount: count, rawBody: resp.body);
    } catch (e) {
      return DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        error: e.toString(),
        rawBody: resp.body,
      );
    }
  }
}
