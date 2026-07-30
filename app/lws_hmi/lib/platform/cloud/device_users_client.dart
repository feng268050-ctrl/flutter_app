import 'dart:convert';

import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Bound cloud users for a device SN (`GET /v1/devices/:sn/users`).
final class DeviceUsersProbeResult {
  const DeviceUsersProbeResult({
    required this.ok,
    required this.userCount,
    this.statusCode = 0,
    this.error,
    this.errorCode,
    this.rawBody,
  });

  final bool ok;
  final int userCount;
  final int statusCode;
  final String? error;
  final String? errorCode;
  final String? rawBody;

  bool get unbound => ok && userCount == 0;

  /// Cloud does not recognize this SN — show “Register This Device”.
  ///
  /// Worker returns HTTP 401 + `errorCode: INVALID_SN` for unknown serials.
  bool get needsRegistration {
    if (statusCode == 401) {
      return true;
    }
    final code = (errorCode ?? '').toUpperCase();
    if (code == 'INVALID_SN') {
      return true;
    }
    final blob = '${error ?? ''} ${rawBody ?? ''}'.toLowerCase();
    return blob.contains('invalid_sn') ||
        blob.contains('invalid device serial');
  }
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
    final parsed = _parseBody(resp.body);
    if (!resp.ok) {
      return DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        statusCode: resp.statusCode,
        error: resp.error ??
            parsed.message ??
            'HTTP ${resp.statusCode}',
        errorCode: parsed.errorCode,
        rawBody: resp.body,
      );
    }
    if (parsed.decodeFailed) {
      return DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        statusCode: resp.statusCode,
        error: 'unexpected body',
        rawBody: resp.body,
      );
    }
    if (parsed.businessCode != null && parsed.businessCode != 200) {
      return DeviceUsersProbeResult(
        ok: false,
        userCount: 0,
        statusCode: resp.statusCode,
        error: parsed.message ?? 'code ${parsed.businessCode}',
        errorCode: parsed.errorCode,
        rawBody: resp.body,
      );
    }
    return DeviceUsersProbeResult(
      ok: true,
      userCount: parsed.userCount,
      statusCode: resp.statusCode,
      errorCode: parsed.errorCode,
      rawBody: resp.body,
    );
  }

  static _ParsedUsersBody _parseBody(String body) {
    if (body.trim().isEmpty) {
      return const _ParsedUsersBody(decodeFailed: true);
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const _ParsedUsersBody(decodeFailed: true);
      }
      final map = Map<String, dynamic>.from(decoded);
      final codeRaw = map['code'];
      final businessCode = codeRaw is num ? codeRaw.toInt() : null;
      final errorCode =
          map['errorCode']?.toString() ?? map['error_code']?.toString();
      final message =
          map['message']?.toString() ?? map['msg']?.toString();
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
      return _ParsedUsersBody(
        businessCode: businessCode,
        errorCode: errorCode,
        message: message,
        userCount: count,
      );
    } catch (_) {
      return const _ParsedUsersBody(decodeFailed: true);
    }
  }
}

final class _ParsedUsersBody {
  const _ParsedUsersBody({
    this.businessCode,
    this.errorCode,
    this.message,
    this.userCount = 0,
    this.decodeFailed = false,
  });

  final int? businessCode;
  final String? errorCode;
  final String? message;
  final int userCount;
  final bool decodeFailed;
}
