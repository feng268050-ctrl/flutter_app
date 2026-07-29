import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_r2_sts_client.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Minimal S3-compatible PutObject using STS credentials (R2).
final class DeviceR2PutObjectClient {
  DeviceR2PutObjectClient({required this.cloudHttp});

  final CloudHttpClient cloudHttp;

  Future<bool> putObject({
    required R2StsCredentials credentials,
    required String objectKey,
    required List<int> bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final endpoint = credentials.endpoint.trim();
    if (endpoint.isEmpty) {
      lwsTrace('r2-put: missing endpoint');
      return false;
    }
    final hostUri = Uri.parse(
      endpoint.contains('://') ? endpoint : 'https://$endpoint',
    );
    final host = hostUri.host;
    final uri = Uri(
      scheme: hostUri.scheme.isEmpty ? 'https' : hostUri.scheme,
      host: host,
      port: hostUri.hasPort ? hostUri.port : null,
      path: '/${credentials.bucket}/$objectKey',
    );

    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    final payloadHash = sha256.convert(bytes).toString();
    final region = credentials.region.isEmpty ? 'auto' : credentials.region;
    final scope = '$dateStamp/$region/s3/aws4_request';

    final canonicalHeaders = StringBuffer()
      ..writeln('content-type:$contentType')
      ..writeln('host:${uri.host}${uri.hasPort ? ':${uri.port}' : ''}')
      ..writeln('x-amz-content-sha256:$payloadHash')
      ..writeln('x-amz-date:$amzDate');
    if (credentials.sessionToken.isNotEmpty) {
      canonicalHeaders.writeln('x-amz-security-token:${credentials.sessionToken}');
    }

    final signedHeaders = credentials.sessionToken.isEmpty
        ? 'content-type;host;x-amz-content-sha256;x-amz-date'
        : 'content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token';

    final canonicalRequest = [
      'PUT',
      uri.path,
      '',
      canonicalHeaders.toString(),
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signingKey = _signingKey(
      secret: credentials.secretAccessKey,
      dateStamp: dateStamp,
      region: region,
      service: 's3',
    );
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();
    final authorization =
        'AWS4-HMAC-SHA256 Credential=${credentials.accessKeyId}/$scope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    final headers = <String, String>{
      'Content-Type': contentType,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      'Authorization': authorization,
    };
    if (credentials.sessionToken.isNotEmpty) {
      headers['x-amz-security-token'] = credentials.sessionToken;
    }

    lwsTrace('r2-put: ${credentials.logSafe} key=$objectKey bytes=${bytes.length}');
    final resp = await cloudHttp.request(
      method: 'PUT',
      url: uri,
      headers: headers,
      bodyBytes: bytes,
      timeout: const Duration(seconds: 120),
      maxBodyBytes: 1024,
    );
    return resp.ok;
  }

  Future<bool> putFile({
    required R2StsCredentials credentials,
    required String objectKey,
    required File file,
    String contentType = 'application/octet-stream',
  }) async {
    final bytes = await file.readAsBytes();
    return putObject(
      credentials: credentials,
      objectKey: objectKey,
      bytes: bytes,
      contentType: contentType,
    );
  }

  static String _amzDate(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _dateStamp(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}';
  }

  static List<int> _signingKey({
    required String secret,
    required String dateStamp,
    required String region,
    required String service,
  }) {
    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    final kDate = hmac(utf8.encode('AWS4$secret'), dateStamp);
    final kRegion = hmac(kDate, region);
    final kService = hmac(kRegion, service);
    return hmac(kService, 'aws4_request');
  }
}
