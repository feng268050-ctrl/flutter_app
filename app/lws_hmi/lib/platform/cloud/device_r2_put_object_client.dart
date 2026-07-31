import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/cloud/cloud_headers.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_r2_sts_client.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Byte progress during streaming PutObject (`readSoFar` / `totalBytes`).
typedef R2PutByteProgress = void Function(int readSoFar, int totalBytes);

/// Minimal S3-compatible PutObject using STS credentials (R2).
final class DeviceR2PutObjectClient {
  DeviceR2PutObjectClient({required this.cloudHttp});

  final CloudHttpClient cloudHttp;

  /// In-memory PutObject (cover JPEG). Uses payload SHA-256.
  Future<bool> putObject({
    required R2StsCredentials credentials,
    required String objectKey,
    required List<int> bytes,
    String contentType = 'application/octet-stream',
  }) {
    return _put(
      credentials: credentials,
      objectKey: objectKey,
      contentType: contentType,
      contentLength: bytes.length,
      payloadHash: sha256.convert(bytes).toString(),
      writeBody: (req) async {
        req.add(bytes);
      },
    );
  }

  /// Streaming file PutObject with optional byte progress (lws-ui video path).
  ///
  /// Uses `UNSIGNED-PAYLOAD` so the body can stream without buffering the
  /// whole MP4 (AWS/R2 SigV4). Cover uploads should keep [putObject].
  Future<bool> putFile({
    required R2StsCredentials credentials,
    required String objectKey,
    required File file,
    String contentType = 'application/octet-stream',
    R2PutByteProgress? onProgress,
  }) async {
    if (!await file.exists()) {
      debugPrint('r2-put: file missing ${file.path}');
      return false;
    }
    final total = await file.length();
    if (total <= 0) {
      debugPrint('r2-put: empty file ${file.path}');
      return false;
    }
    return _put(
      credentials: credentials,
      objectKey: objectKey,
      contentType: contentType,
      contentLength: total,
      payloadHash: 'UNSIGNED-PAYLOAD',
      writeBody: (req) async {
        final raf = await file.open();
        try {
          const chunkSize = 64 * 1024;
          var read = 0;
          onProgress?.call(0, total);
          while (true) {
            final chunk = await raf.read(chunkSize);
            if (chunk.isEmpty) {
              break;
            }
            req.add(chunk);
            read += chunk.length;
            onProgress?.call(read, total);
          }
          if (read < total) {
            onProgress?.call(total, total);
          }
        } finally {
          await raf.close();
        }
      },
    );
  }

  Future<bool> _put({
    required R2StsCredentials credentials,
    required String objectKey,
    required String contentType,
    required int contentLength,
    required String payloadHash,
    required Future<void> Function(HttpClientRequest req) writeBody,
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

    lwsTrace(
      'r2-put: ${credentials.logSafe} key=$objectKey bytes=$contentLength',
    );

    HttpClient? client;
    try {
      client = await cloudHttp.openClient(
        timeout: Duration(
          seconds: math.max(120, (contentLength / (256 * 1024)).ceil() + 60),
        ),
      );
      final timeout = Duration(
        seconds: math.max(120, (contentLength / (128 * 1024)).ceil() + 60),
      );
      final req = await client.openUrl('PUT', uri).timeout(timeout);
      final merged = {
        ...CloudHeaders.forRequest(appVersion: cloudHttp.appVersion),
        ...headers,
      };
      merged.forEach(req.headers.set);
      req.contentLength = contentLength;
      await writeBody(req);
      final resp = await req.close().timeout(timeout);
      final bodyBytes = <int>[];
      await for (final chunk in resp) {
        if (bodyBytes.length >= 1024) {
          break;
        }
        bodyBytes.addAll(chunk.take(1024 - bodyBytes.length));
      }
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!ok) {
        debugPrint(
          'r2-put: failed status=${resp.statusCode} '
          'body=${utf8.decode(bodyBytes, allowMalformed: true)}',
        );
      }
      return ok;
    } catch (e) {
      debugPrint('r2-put: exception $e');
      return false;
    } finally {
      client?.close(force: true);
    }
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
