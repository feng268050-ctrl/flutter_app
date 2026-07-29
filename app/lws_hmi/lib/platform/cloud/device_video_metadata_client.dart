import 'dart:convert';

import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Registers process-video metadata before/with object upload (lws-ui route).
final class DeviceVideoMetadataClient {
  DeviceVideoMetadataClient({required this.cloudHttp});

  final CloudHttpClient cloudHttp;

  /// Relative path used by lws-ui Retrofit `ProcessVideoRemoteApi`.
  static const relativePath = 'videoMange/video/uploadVideoAndProcessData';

  Future<int?> uploadVideoAndProcessData({
    required Uri pinnedBase,
    required Map<String, Object?> body,
  }) async {
    final base = DeviceApiOriginConfig.stripTrailingSlash(pinnedBase);
    final prefix = base.path;
    final path = (prefix.isEmpty || prefix == '/')
        ? '/$relativePath'
        : (prefix.endsWith('/')
            ? '$prefix$relativePath'
            : '$prefix/$relativePath');
    final url = base.replace(path: path);
    final resp = await cloudHttp.postJson(url, jsonBody: body);
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
      if (data is num) {
        return data.toInt();
      }
      if (data is String) {
        return int.tryParse(data);
      }
      if (data is Map && data['videoId'] is num) {
        return (data['videoId'] as num).toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
