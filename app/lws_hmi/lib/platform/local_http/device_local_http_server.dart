import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/network.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/local_http/api_result.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Embedded LAN HTTP API on `0.0.0.0:5580` (dart:io; shelf deferred for Flutter 3.24.4).
final class DeviceLocalHttpServer {
  DeviceLocalHttpServer({
    this.port = 5580,
    this.processVideoRepository,
    this.processLibrary,
    this.sshDebug,
  });

  final int port;
  ProcessVideoRepository? processVideoRepository;
  ProcessLibraryController? processLibrary;
  SshDebugController? sshDebug;

  HttpServer? _server;
  bool get isRunning => _server != null;

  Future<bool> start() async {
    if (_server != null) {
      return true;
    }
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = server;
      lwsTrace('local-http: listening on 0.0.0.0:$port');
      server.listen(_handle, onError: (Object e) {
        debugPrint('local-http: accept error: $e');
      });
      return true;
    } catch (e) {
      debugPrint('local-http: bind failed on $port: $e');
      _server = null;
      return false;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/lasercyber') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.text;
        request.response.write('Hello LaserCyber');
        await request.response.close();
        return;
      }

      if (path == '/v1/videos' || path.startsWith('/v1/videos/')) {
        await _handleVideos(request);
        return;
      }
      if (path == '/v1/process-library' ||
          path.startsWith('/v1/process-parameters')) {
        await _handleProcessLibrary(request);
        return;
      }
      if (path == '/v1/adb' && request.method == 'POST') {
        await _handleAdb(request);
        return;
      }
      if (path.startsWith('/v1/monitor/') || path.startsWith('/v1/camera/')) {
        await _writeJson(
          request,
          HttpStatus.notImplemented,
          ApiResult.fail('not implemented', code: 501),
        );
        return;
      }

      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('not found', code: 404),
      );
    } catch (e) {
      debugPrint('local-http: handler error: $e');
      try {
        await _writeJson(
          request,
          HttpStatus.internalServerError,
          ApiResult.fail(e.toString(), code: 500),
        );
      } catch (_) {}
    }
  }

  Future<void> _handleVideos(HttpRequest request) async {
    final repo = processVideoRepository;
    if (repo == null) {
      await _writeJson(
        request,
        HttpStatus.serviceUnavailable,
        ApiResult.fail('videos backend unavailable'),
      );
      return;
    }
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/v1/videos') {
      final page = int.tryParse(request.uri.queryParameters['page'] ?? '') ?? 1;
      final pageSize =
          (int.tryParse(request.uri.queryParameters['pageSize'] ?? '') ?? 10)
              .clamp(1, 100);
      final offset = (page - 1) * pageSize;
      await repo.open();
      final total = await repo.count();
      final rows = await repo.list(limit: pageSize, offset: offset);
      final list = [
        for (final r in rows)
          {
            'videoId': r.videoId,
            'processType': r.processType.wireValue,
            'materialType': r.materialType?.storageValue,
            'createTime': r.createTimeMs,
            'duration': r.durationMs,
            'resolution': r.resolution,
            'fileSize': r.fileSize,
            'uploadStatus': r.uploadStatus,
            'uploadProgress': r.uploadProgress,
            'coverUrl': r.coverUrl,
            'processParameters': r.snapshot?.toJson(),
          },
      ];
      await _writeJson(
        request,
        HttpStatus.ok,
        ApiResult.ok(data: {'list': list, 'total': total}),
      );
      return;
    }

    final idMatch = RegExp(r'^/v1/videos/(\d+)$').firstMatch(path);
    if (idMatch != null) {
      final id = int.parse(idMatch.group(1)!);
      if (request.method == 'GET') {
        final row = await repo.getById(id);
        if (row == null) {
          await _writeJson(
            request,
            HttpStatus.notFound,
            ApiResult.fail('not found'),
          );
          return;
        }
        await _writeJson(
          request,
          HttpStatus.ok,
          ApiResult.ok(data: {
            'videoId': row.videoId,
            'processType': row.processType.wireValue,
            'materialType': row.materialType?.storageValue,
            'createTime': row.createTimeMs,
          }),
        );
        return;
      }
      if (request.method == 'DELETE') {
        final ok = await repo.deleteById(id);
        await _writeJson(
          request,
          HttpStatus.ok,
          ok ? ApiResult.ok() : ApiResult.fail('delete failed'),
        );
        return;
      }
    }

    if (path.endsWith('/stream') && request.method == 'GET') {
      final m = RegExp(r'^/v1/videos/(\d+)/stream$').firstMatch(path);
      if (m != null) {
        final row = await repo.getById(int.parse(m.group(1)!));
        final filePath = row?.videoPath;
        if (filePath == null || filePath.isEmpty || !File(filePath).existsSync()) {
          await _writeJson(
            request,
            HttpStatus.notFound,
            ApiResult.fail('file missing'),
          );
          return;
        }
        final file = File(filePath);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType('video', 'mp4');
        await request.response.addStream(file.openRead());
        await request.response.close();
        return;
      }
    }

    await _writeJson(
      request,
      HttpStatus.notImplemented,
      ApiResult.fail('videos route not implemented', code: 501),
    );
  }

  Future<void> _handleProcessLibrary(HttpRequest request) async {
    final library = processLibrary;
    if (library == null) {
      await _writeJson(
        request,
        HttpStatus.serviceUnavailable,
        ApiResult.fail('process library unavailable'),
      );
      return;
    }
    await library.initialize();
    if (request.method == 'GET' && request.uri.path == '/v1/process-library') {
      final processType =
          int.tryParse(request.uri.queryParameters['processType'] ?? '');
      final presets = library.presets.where((p) {
        if (processType == null) {
          return true;
        }
        return p.processType.wireValue == processType;
      }).map((p) {
        return {
          'id': p.id,
          'name': p.name,
          'processType': p.processType.wireValue,
          'uuid': p.uuid,
        };
      }).toList();
      await _writeJson(request, HttpStatus.ok, ApiResult.ok(data: presets));
      return;
    }
    await _writeJson(
      request,
      HttpStatus.notImplemented,
      ApiResult.fail('process-parameters mutation not implemented', code: 501),
    );
  }

  Future<void> _handleAdb(HttpRequest request) async {
    final ssh = sshDebug;
    if (ssh == null) {
      await _writeJson(
        request,
        HttpStatus.notImplemented,
        ApiResult.fail('LAN SSH debug unavailable (ADB is Android-only)', code: 501),
      );
      return;
    }
    try {
      await ssh.setEnabled(true);
      await _writeJson(
        request,
        HttpStatus.ok,
        ApiResult.ok(data: {
          'mode': 'lan_ssh_debug',
          'note': 'Linux maps /v1/adb to LAN SSH debug',
        }),
      );
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.internalServerError,
        ApiResult.fail(e.toString()),
      );
    }
  }

  Future<void> _writeJson(
    HttpRequest request,
    int status,
    ApiResult result,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(result.encode());
    await request.response.close();
  }
}
