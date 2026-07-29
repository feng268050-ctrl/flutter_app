import 'dart:convert';

import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Temporary R2 credentials from Worker STS.
final class R2StsCredentials {
  const R2StsCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.sessionToken,
    required this.bucket,
    required this.endpoint,
    this.region = 'auto',
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;
  final String bucket;
  final String endpoint;
  final String region;

  /// Redacted summary safe for info logs.
  String get logSafe =>
      'R2Sts(bucket=$bucket, endpoint=$endpoint, keyId=${accessKeyId.length > 4 ? accessKeyId.substring(0, 4) : '****'}…)';
}

final class DeviceR2StsClient {
  DeviceR2StsClient({required this.cloudHttp});

  final CloudHttpClient cloudHttp;

  Future<R2StsCredentials?> fetchSts({
    required Uri pinnedBase,
    Map<String, Object?>? body,
  }) async {
    final url = DeviceApiOriginConfig.joinUnderBase(
      pinnedBase,
      '/v1/storage/r2/sts',
    );
    final resp = await cloudHttp.postJson(url, jsonBody: body ?? const {});
    if (!resp.ok) {
      return null;
    }
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final code = map['code'];
      if (code is num && code.toInt() != 200) {
        return null;
      }
      final data = map['data'];
      if (data is! Map) {
        return null;
      }
      final d = Map<String, dynamic>.from(data);
      final accessKeyId =
          (d['accessKeyId'] ?? d['access_key_id'])?.toString() ?? '';
      final secret =
          (d['secretAccessKey'] ?? d['secret_access_key'])?.toString() ?? '';
      final token =
          (d['sessionToken'] ?? d['session_token'])?.toString() ?? '';
      final bucket = (d['bucket'] ?? d['bucketName'])?.toString() ?? '';
      final endpoint = (d['endpoint'] ?? d['accountEndpoint'])?.toString() ?? '';
      final region = (d['region'] ?? 'auto').toString();
      if (accessKeyId.isEmpty || secret.isEmpty || bucket.isEmpty) {
        return null;
      }
      return R2StsCredentials(
        accessKeyId: accessKeyId,
        secretAccessKey: secret,
        sessionToken: token,
        bucket: bucket,
        endpoint: endpoint,
        region: region,
      );
    } catch (_) {
      return null;
    }
  }
}
