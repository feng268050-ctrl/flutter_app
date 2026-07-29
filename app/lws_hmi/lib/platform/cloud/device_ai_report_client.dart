import 'dart:convert';

import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

/// Multipart AI report upload (`POST /v1/devices/:sn/ai-report`).
final class DeviceAiReportClient {
  DeviceAiReportClient({required this.cloudHttp});

  final CloudHttpClient cloudHttp;

  Future<bool> uploadAiReport({
    required Uri pinnedBase,
    required String deviceSn,
    required List<int> imageBytes,
    required Map<String, Object?> statJson,
    String filename = 'ai.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final sn = deviceSn.trim();
    if (sn.isEmpty || imageBytes.isEmpty) {
      return false;
    }
    final url = DeviceApiOriginConfig.joinUnderBase(
      pinnedBase,
      '/v1/devices/${Uri.encodeComponent(sn)}/ai-report',
    );
    const boundary = '----lwsHmiAiReportBoundary7MA4YWxkTrZu0gW';
    final body = <int>[];
    void write(String s) => body.addAll(utf8.encode(s));

    write('--$boundary\r\n');
    write('Content-Disposition: form-data; name="stat"\r\n');
    write('Content-Type: application/json; charset=utf-8\r\n\r\n');
    write('${jsonEncode(statJson)}\r\n');

    write('--$boundary\r\n');
    write(
      'Content-Disposition: form-data; name="image"; filename="$filename"\r\n',
    );
    write('Content-Type: $contentType\r\n\r\n');
    body.addAll(imageBytes);
    write('\r\n--$boundary--\r\n');

    final resp = await cloudHttp.request(
      method: 'POST',
      url: url,
      headers: {
        'Content-Type': 'multipart/form-data; boundary=$boundary',
      },
      bodyBytes: body,
      timeout: const Duration(seconds: 60),
    );
    if (!resp.ok) {
      return false;
    }
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['code'] is num) {
        return (decoded['code'] as num).toInt() == 200;
      }
      return true;
    } catch (_) {
      return resp.ok;
    }
  }
}
