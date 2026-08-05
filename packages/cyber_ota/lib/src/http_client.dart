import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// HTTP client for manifest fetch and OTA archive download.
abstract interface class OtaHttpClient {
  Future<Map<String, dynamic>> getJson(String url);

  Future<void> download(
    String url,
    String destinationPath, {
    void Function(int bytesReceived, int? bytesTotal)? onProgress,
  });
}

/// Default [OtaHttpClient] backed by `package:http`.
final class HttpOtaClient implements OtaHttpClient {
  HttpOtaClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<String, dynamic>> getJson(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('GET $url failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('manifest response is not a JSON object', decoded);
    }
    return decoded;
  }

  @override
  Future<void> download(
    String url,
    String destinationPath, {
    void Function(int bytesReceived, int? bytesTotal)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final streamed = await _client.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException('GET $url failed: HTTP ${streamed.statusCode}');
    }

    final contentLength = streamed.contentLength;
    final total = contentLength != null && contentLength >= 0 ? contentLength : null;
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var received = 0;

    try {
      await for (final chunk in streamed.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    onProgress?.call(received, total ?? received);
  }
}

/// Fake HTTP client for tests.
final class FakeOtaHttpClient implements OtaHttpClient {
  FakeOtaHttpClient({
    this.manifestJson,
    this.downloadHandler,
  });

  Map<String, dynamic>? manifestJson;
  Future<void> Function(
    String url,
    String destinationPath, {
    void Function(int bytesReceived, int? bytesTotal)? onProgress,
  })? downloadHandler;

  final downloads = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String url) async {
    if (manifestJson == null) {
      throw StateError('manifestJson not configured');
    }
    return Map<String, dynamic>.from(manifestJson!);
  }

  @override
  Future<void> download(
    String url,
    String destinationPath, {
    void Function(int bytesReceived, int? bytesTotal)? onProgress,
  }) async {
    downloads.add(url);
    if (downloadHandler != null) {
      await downloadHandler!(url, destinationPath, onProgress: onProgress);
      return;
    }
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    await file.writeAsString('fake-package');
    onProgress?.call(12, 12);
  }
}
