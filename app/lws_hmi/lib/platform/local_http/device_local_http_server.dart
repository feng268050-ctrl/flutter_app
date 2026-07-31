import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cyber_hal/network.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_library_controller.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/local_http/api_result.dart';
import 'package:lws_hmi/platform/local_http/local_http_video_row.dart';
import 'package:lws_hmi/platform/local_http/monitor_alerts_sse_hub.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_sse_hub.dart';
import 'package:lws_hmi/features/ai/application/camera_ai_http_publisher.dart';
import 'package:lws_hmi/features/ai/application/ai_daemon_supervisor.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_session.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_timeline.dart';
import 'package:lws_hmi/platform/local_http/multipart_form_data.dart';
import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Result for camera record / overlay LAN handlers.
final class LocalHttpCameraActionResult {
  const LocalHttpCameraActionResult({
    required this.ok,
    this.httpStatus = HttpStatus.ok,
    this.message = 'ok',
    this.data,
  });

  final bool ok;
  final int httpStatus;
  final String message;
  final Object? data;

  static LocalHttpCameraActionResult success({Object? data}) =>
      LocalHttpCameraActionResult(ok: true, data: data);

  static LocalHttpCameraActionResult fail(
    String message, {
    int httpStatus = HttpStatus.badRequest,
  }) =>
      LocalHttpCameraActionResult(
        ok: false,
        httpStatus: httpStatus,
        message: message,
      );
}

/// Embedded LAN HTTP API on `0.0.0.0:5580` (lws-ui `DeviceLocalHttpServer` parity).
final class DeviceLocalHttpServer {
  DeviceLocalHttpServer({
    this.port = 5580,
    this.processVideoRepository,
    this.processLibrary,
    this.sshDebug,
    MonitorStatSseHub? monitorStatHub,
    MonitorAlertsSseHub? monitorAlertsHub,
    CameraAiHttpPublisher? cameraAiPublisher,
    this.cameraRecordHandler,
    this.cameraShowOverlayHandler,
    this.cameraAiAvailable,
    this.processVideoAiAvailable,
    ProcessVideoAiSessionRegistry? processVideoAiRegistry,
  })  : monitorStatHub = monitorStatHub ?? MonitorStatSseHub(),
        monitorAlertsHub = monitorAlertsHub ?? MonitorAlertsSseHub(),
        cameraAiPublisher = cameraAiPublisher ?? CameraAiHttpPublisher(),
        processVideoAiRegistry =
            processVideoAiRegistry ?? ProcessVideoAiSessionRegistry.instance;

  final int port;
  ProcessVideoRepository? processVideoRepository;
  ProcessLibraryController? processLibrary;
  SshDebugController? sshDebug;

  final MonitorStatSseHub monitorStatHub;
  final MonitorAlertsSseHub monitorAlertsHub;
  final CameraAiHttpPublisher cameraAiPublisher;
  final ProcessVideoAiSessionRegistry processVideoAiRegistry;

  /// `switch` is `on` or `off`.
  Future<LocalHttpCameraActionResult> Function(String switchValue)?
      cameraRecordHandler;

  Future<LocalHttpCameraActionResult> Function(Map<String, Object?> body)?
      cameraShowOverlayHandler;

  /// When null, camera AI is treated as unavailable.
  Future<bool> Function()? cameraAiAvailable;

  /// When null, falls back to [AiDaemonSupervisor.instance.isReady].
  Future<bool> Function()? processVideoAiAvailable;

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
      if (path == '/v1/monitor/stat' && request.method == 'GET') {
        await _handleMonitorStatSse(request);
        return;
      }
      if (path == '/v1/monitor/alerts' && request.method == 'GET') {
        await _handleMonitorAlertsSse(request);
        return;
      }
      if (path == '/v1/camera/record' && request.method == 'POST') {
        await _handleCameraRecord(request);
        return;
      }
      if (path == '/v1/camera/show-overlay' && request.method == 'POST') {
        await _handleCameraShowOverlay(request);
        return;
      }
      if (path == '/v1/camera/ai' && request.method == 'GET') {
        await _handleCameraAi(request);
        return;
      }

      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('not_found', code: 404),
      );
    } catch (e) {
      debugPrint('local-http: handler error: $e');
      try {
        await _writeJson(
          request,
          HttpStatus.internalServerError,
          ApiResult.fail('internal_error', code: 500),
        );
      } catch (_) {}
    }
  }

  // --- Videos ----------------------------------------------------------------

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
      await _videoList(request, repo);
      return;
    }
    if (request.method == 'POST' && path == '/v1/videos') {
      await _videoUpload(request, repo);
      return;
    }

    final aiReplay = RegExp(r'^/v1/videos/([^/]+)/ai/replay$').firstMatch(path);
    if (aiReplay != null && request.method == 'GET') {
      await _videoAiReplay(request, repo, Uri.decodeComponent(aiReplay.group(1)!));
      return;
    }
    final aiLive = RegExp(r'^/v1/videos/([^/]+)/ai$').firstMatch(path);
    if (aiLive != null && request.method == 'GET') {
      await _videoAiSse(request, repo, Uri.decodeComponent(aiLive.group(1)!));
      return;
    }

    final stream = RegExp(r'^/v1/videos/([^/]+)/stream$').firstMatch(path);
    if (stream != null && request.method == 'GET') {
      await _videoStream(request, repo, Uri.decodeComponent(stream.group(1)!));
      return;
    }

    final one = RegExp(r'^/v1/videos/([^/]+)$').firstMatch(path);
    if (one != null) {
      final videoId = Uri.decodeComponent(one.group(1)!);
      if (request.method == 'GET') {
        await repo.open();
        final row = await repo.findByVideoId(videoId);
        if (row == null) {
          await _writeJson(
            request,
            HttpStatus.notFound,
            ApiResult.fail('video_not_found', code: 404),
          );
          return;
        }
        await _writeJson(
          request,
          HttpStatus.ok,
          ApiResult.ok(data: LocalHttpVideoRow.fromRecord(row)),
        );
        return;
      }
      if (request.method == 'DELETE') {
        await repo.open();
        final ok = await repo.deleteByVideoId(videoId);
        if (!ok) {
          await _writeJson(
            request,
            HttpStatus.notFound,
            ApiResult.fail('video_not_found', code: 404),
          );
          return;
        }
        await _writeJson(request, HttpStatus.ok, ApiResult.ok());
        return;
      }
    }

    await _writeJson(
      request,
      HttpStatus.notFound,
      ApiResult.fail('not_found', code: 404),
    );
  }

  Future<void> _videoList(
    HttpRequest request,
    ProcessVideoRepository repo,
  ) async {
    final q = request.uri.queryParameters;
    final page = int.tryParse(q['page'] ?? '') ?? 1;
    final pageSize = (int.tryParse(q['pageSize'] ?? '') ?? 10).clamp(1, 100);
    final processType = int.tryParse(q['processType'] ?? '');
    final materialType = int.tryParse(q['materialType'] ?? '');
    final uploadStatus = int.tryParse(q['uploadStatus'] ?? '');
    final order = q['order'] ?? 'date_desc';
    await repo.open();
    final pageResult = await repo.query(
      ProcessVideoListQuery(
        page: page < 1 ? 1 : page,
        pageSize: pageSize,
        processType: processType,
        materialType: materialType,
        startDateYmd: q['startDate'],
        endDateYmd: q['endDate'],
        orderAsc: order == 'date_asc',
        uploadStatus: uploadStatus,
      ),
    );
    await _writeJson(
      request,
      HttpStatus.ok,
      ApiResult.ok(data: {
        'list': [
          for (final r in pageResult.list) LocalHttpVideoRow.fromRecord(r),
        ],
        'total': pageResult.total,
      }),
    );
  }

  Future<void> _videoUpload(
    HttpRequest request,
    ProcessVideoRepository repo,
  ) async {
    final parsed = await MultipartFormData.parse(request);
    if (parsed == null) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_multipart', code: 400),
      );
      return;
    }
    final tempPath = parsed.files['file'];
    if (tempPath == null || tempPath.isEmpty) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('missing_file', code: 400),
      );
      return;
    }
    final processType = int.tryParse(parsed.fields['processType'] ?? '');
    if (processType == null) {
      await _cleanupTemp(tempPath);
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_processType', code: 400),
      );
      return;
    }
    final materialType = int.tryParse(parsed.fields['materialType'] ?? '');
    if (materialType == null) {
      await _cleanupTemp(tempPath);
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_materialType', code: 400),
      );
      return;
    }
    final source = File(tempPath);
    if (!source.existsSync() || source.lengthSync() <= 0) {
      await _cleanupTemp(tempPath);
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('empty_file', code: 400),
      );
      return;
    }

    final videoId = _newVideoId();
    final destDir = Directory('${OsPaths.varHmi}/process_videos');
    await destDir.create(recursive: true);
    final dest = File('${destDir.path}/$videoId.mp4');
    try {
      await source.copy(dest.path);
    } catch (e) {
      await _cleanupTemp(tempPath);
      await _writeJson(
        request,
        HttpStatus.internalServerError,
        ApiResult.fail('save_failed', code: 500),
      );
      return;
    } finally {
      await _cleanupTemp(tempPath);
    }

    final probe = await _probeVideo(dest);
    if (probe.durationMs <= 0) {
      try {
        await dest.delete();
      } catch (_) {}
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_video_duration', code: 400),
      );
      return;
    }
    if (probe.resolution == null || probe.resolution!.isEmpty) {
      try {
        await dest.delete();
      } catch (_) {}
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_video_resolution', code: 400),
      );
      return;
    }

    final paramsRaw = parsed.fields['processParameters']?.trim() ?? '';
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await repo.open();
    final saved = await repo.insert(
      ProcessVideoRecord(
        videoId: videoId,
        videoPath: dest.path,
        processType: ProcessType.fromWireValue(processType),
        materialType: MaterialType.fromStorageValue(materialType),
        processParametersJson: paramsRaw,
        fileSize: dest.lengthSync(),
        durationMs: probe.durationMs,
        resolution: probe.resolution,
        createTimeMs: now,
      ),
    );
    await _writeJson(
      request,
      HttpStatus.ok,
      ApiResult.ok(data: LocalHttpVideoRow.fromRecord(saved)),
    );
  }

  Future<void> _videoStream(
    HttpRequest request,
    ProcessVideoRepository repo,
    String videoId,
  ) async {
    await repo.open();
    final row = await repo.findByVideoId(videoId);
    final filePath = row?.videoPath;
    if (filePath == null || filePath.isEmpty || !File(filePath).existsSync()) {
      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('file_missing', code: 404),
      );
      return;
    }
    final file = File(filePath);
    final length = file.lengthSync();
    final range = request.headers.value(HttpHeaders.rangeHeader);
    request.response.headers.contentType = ContentType('video', 'mp4');
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (range != null && range.startsWith('bytes=')) {
      final spec = range.substring(6);
      final parts = spec.split('-');
      final start = int.tryParse(parts[0]) ?? 0;
      final end = parts.length > 1 && parts[1].isNotEmpty
          ? (int.tryParse(parts[1]) ?? (length - 1))
          : length - 1;
      final clampedStart = start.clamp(0, length - 1);
      final clampedEnd = end.clamp(clampedStart, length - 1);
      final contentLen = clampedEnd - clampedStart + 1;
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $clampedStart-$clampedEnd/$length',
      );
      request.response.contentLength = contentLen;
      await request.response.addStream(file.openRead(clampedStart, clampedEnd + 1));
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = length;
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }

  Future<({int durationMs, String? resolution})> _probeVideo(File file) async {
    try {
      final dur = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'csv=p=0',
        file.path,
      ]).timeout(const Duration(seconds: 5));
      final res = await Process.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=width,height',
        '-of',
        'csv=p=0:s=x',
        file.path,
      ]).timeout(const Duration(seconds: 5));
      final seconds = double.tryParse((dur.stdout as String).trim());
      final resolution = (res.stdout as String).trim();
      if (seconds != null && seconds > 0 && resolution.contains('x')) {
        return (
          durationMs: (seconds * 1000).round(),
          resolution: resolution,
        );
      }
    } catch (e) {
      debugPrint('local-http: ffprobe soft-fail: $e');
    }
    // No ffprobe: accept non-empty MP4 with defaults (Linux appliance fallback).
    if (file.lengthSync() > 0) {
      return (durationMs: 1000, resolution: '1920x1080');
    }
    return (durationMs: 0, resolution: null);
  }

  String _newVideoId() {
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
    final n = Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$ms-$n';
  }

  Future<void> _cleanupTemp(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  // --- Process library -------------------------------------------------------

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
      if (processType == null) {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('missing_process_type', code: 400),
        );
        return;
      }
      final presets = library.presets
          .where((p) => p.processType.wireValue == processType)
          .map(_presetWire)
          .toList();
      await _writeJson(request, HttpStatus.ok, ApiResult.ok(data: presets));
      return;
    }

    if (request.uri.path == '/v1/process-parameters' &&
        request.method == 'POST') {
      await _createProcessParameter(request, library);
      return;
    }

    // lws-ui has no GET collection for process-parameters; keep not_found.
    if (request.uri.path == '/v1/process-parameters' &&
        request.method == 'GET') {
      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('not_found', code: 404),
      );
      return;
    }

    final idMatch =
        RegExp(r'^/v1/process-parameters/([^/]+)(/set-default)?$')
            .firstMatch(request.uri.path);
    if (idMatch != null) {
      final id = Uri.decodeComponent(idMatch.group(1)!);
      final isSetDefault = idMatch.group(2) != null;
      if (isSetDefault && request.method == 'POST') {
        await _setDefaultProcessParameter(request, library, id);
        return;
      }
      if (request.method == 'GET') {
        final preset = await _findPreset(library, id);
        if (preset == null) {
          await _writeJson(
            request,
            HttpStatus.notFound,
            ApiResult.fail('not_found', code: 404),
          );
          return;
        }
        await _writeJson(
          request,
          HttpStatus.ok,
          ApiResult.ok(data: _presetWire(preset)),
        );
        return;
      }
      if (request.method == 'PUT') {
        await _updateProcessParameter(request, library, id);
        return;
      }
      if (request.method == 'DELETE') {
        await _deleteProcessParameter(request, library, id);
        return;
      }
    }

    await _writeJson(
      request,
      HttpStatus.notFound,
      ApiResult.fail('not_found', code: 404),
    );
  }

  Map<String, Object?> _presetWire(ProcessPreset p) => {
        'id': p.id ?? p.uuid,
        'uuid': p.uuid,
        'name': p.name,
        'processType': p.processType.wireValue,
        'materialType': p.materialType?.storageValue,
        'materialName': p.materialName,
        'thickness': p.thickness,
        'gear': p.gear,
        'parameters': p.parameters.toJson(),
        'dataType': p.isBuiltin ? 1 : 2,
        'isBuiltin': p.isBuiltin,
        'kind': p.kind.storageValue,
      };

  Future<ProcessPreset?> _findPreset(
    ProcessLibraryController library,
    String id,
  ) async {
    final byUuid = await library.repository.findByUuid(id);
    if (byUuid != null) {
      return byUuid;
    }
    final asInt = int.tryParse(id);
    if (asInt == null) {
      return null;
    }
    for (final p in library.presets) {
      if (p.id == asInt) {
        return p;
      }
    }
    return null;
  }

  Future<Map<String, Object?>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('invalid_json');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<void> _createProcessParameter(
    HttpRequest request,
    ProcessLibraryController library,
  ) async {
    try {
      final map = await _readJsonBody(request);
      final name = map['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('invalid_json', code: 400),
        );
        return;
      }
      final processTypeRaw = map['processType'] ?? map['process_type'];
      if (processTypeRaw == null) {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('invalid_json', code: 400),
        );
        return;
      }
      final processType = ProcessType.fromWireValue(
        processTypeRaw is num
            ? processTypeRaw.toInt()
            : int.parse(processTypeRaw.toString()),
      );
      final materialRaw = map['materialType'] ?? map['material_type'];
      MaterialType? material;
      if (materialRaw is num) {
        material = MaterialType.fromStorageValue(materialRaw.toInt());
      }
      final paramsRaw = map['parameters'];
      final parameters = paramsRaw is Map
          ? ProcessParameters.fromJson(Map<String, dynamic>.from(paramsRaw))
          : const ProcessParameters.empty();
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final saved = await library.saveUser(
        ProcessPreset(
          uuid: 'lan-$now',
          name: name,
          kind: ProcessPresetKind.user,
          source: 'lan',
          isBuiltin: false,
          processType: processType,
          materialType: material,
          materialName: map['materialName']?.toString(),
          thickness: (map['thickness'] as num?)?.toDouble(),
          gear: (map['gear'] as num?)?.toInt(),
          parameters: parameters,
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );
      // lws-ui create returns `{ id }` only.
      await _writeJson(
        request,
        HttpStatus.ok,
        ApiResult.ok(data: {'id': saved.id ?? saved.uuid}),
      );
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_json', code: 400),
      );
    }
  }

  Future<void> _updateProcessParameter(
    HttpRequest request,
    ProcessLibraryController library,
    String id,
  ) async {
    try {
      final existing = await _findPreset(library, id);
      if (existing == null) {
        await _writeJson(
          request,
          HttpStatus.notFound,
          ApiResult.fail('not_found', code: 404),
        );
        return;
      }
      if (existing.isBuiltin) {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('builtin_readonly', code: 400),
        );
        return;
      }
      final map = await _readJsonBody(request);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final paramsRaw = map['parameters'];
      final parameters = paramsRaw is Map
          ? ProcessParameters.fromJson(Map<String, dynamic>.from(paramsRaw))
          : existing.parameters;
      await library.saveUser(
        existing.copyWith(
          name: map['name']?.toString().trim().isNotEmpty == true
              ? map['name'].toString().trim()
              : existing.name,
          materialName: map['materialName']?.toString() ?? existing.materialName,
          thickness:
              (map['thickness'] as num?)?.toDouble() ?? existing.thickness,
          gear: (map['gear'] as num?)?.toInt() ?? existing.gear,
          parameters: parameters,
          updatedAtMs: now,
        ),
      );
      await _writeJson(request, HttpStatus.ok, ApiResult.ok());
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_json', code: 400),
      );
    }
  }

  Future<void> _deleteProcessParameter(
    HttpRequest request,
    ProcessLibraryController library,
    String id,
  ) async {
    try {
      final existing = await _findPreset(library, id);
      if (existing == null) {
        await _writeJson(
          request,
          HttpStatus.notFound,
          ApiResult.fail('not_found', code: 404),
        );
        return;
      }
      if (existing.isBuiltin) {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('cannot_delete_non_engineer', code: 400),
        );
        return;
      }
      await library.deleteUser(existing);
      await _writeJson(request, HttpStatus.ok, ApiResult.ok());
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail(e.toString(), code: 400),
      );
    }
  }

  Future<void> _setDefaultProcessParameter(
    HttpRequest request,
    ProcessLibraryController library,
    String id,
  ) async {
    try {
      final existing = await _findPreset(library, id);
      if (existing == null) {
        await _writeJson(
          request,
          HttpStatus.notFound,
          ApiResult.fail('not_found', code: 404),
        );
        return;
      }
      final result = await library.apply(existing);
      if (!result.isSuccess) {
        await _writeJson(
          request,
          HttpStatus.internalServerError,
          ApiResult.fail(result.failure?.name ?? 'apply_failed', code: 500),
        );
        return;
      }
      await _writeJson(request, HttpStatus.ok, ApiResult.ok());
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.internalServerError,
        ApiResult.fail(e.toString(), code: 500),
      );
    }
  }

  // --- Monitor SSE -----------------------------------------------------------

  Future<void> _handleMonitorStatSse(HttpRequest request) async {
    final sub = monitorStatHub.acquire();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      'text/event-stream; charset=utf-8',
    );
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.response.headers.set('X-Accel-Buffering', 'no');
    request.response.bufferOutput = false;

    var closed = false;
    unawaited(request.response.done.then((_) {
      closed = true;
      sub.closeFromClient();
    }));

    try {
      await for (final frame in sub.frames) {
        if (closed) {
          break;
        }
        request.response.add(frame);
        await request.response.flush();
      }
    } catch (e) {
      debugPrint('local-http: monitor stat sse end: $e');
    } finally {
      sub.closeFromClient();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleMonitorAlertsSse(HttpRequest request) async {
    final sub = await monitorAlertsHub.acquire();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      'text/event-stream; charset=utf-8',
    );
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.response.headers.set('X-Accel-Buffering', 'no');
    request.response.bufferOutput = false;

    var closed = false;
    unawaited(request.response.done.then((_) {
      closed = true;
      sub.closeFromClient();
    }));

    try {
      await for (final frame in sub.frames) {
        if (closed) {
          break;
        }
        request.response.add(frame);
        await request.response.flush();
      }
    } catch (e) {
      debugPrint('local-http: monitor alerts sse end: $e');
    } finally {
      sub.closeFromClient();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  // --- Camera ----------------------------------------------------------------

  Future<void> _handleCameraRecord(HttpRequest request) async {
    final handler = cameraRecordHandler;
    if (handler == null) {
      await _writeJson(
        request,
        HttpStatus.serviceUnavailable,
        ApiResult.fail('camera_unavailable', code: 503),
      );
      return;
    }
    try {
      final map = await _readJsonBody(request);
      final sw = map['switch']?.toString().trim().toLowerCase() ?? '';
      if (sw != 'on' && sw != 'off') {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('invalid_switch', code: 400),
        );
        return;
      }
      final result = await handler(sw);
      if (!result.ok) {
        await _writeJson(
          request,
          result.httpStatus,
          ApiResult.fail(result.message, code: result.httpStatus),
        );
        return;
      }
      await _writeJson(
        request,
        HttpStatus.ok,
        ApiResult.ok(data: result.data ?? {'switch': sw}),
      );
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_switch', code: 400),
      );
    }
  }

  Future<void> _handleCameraShowOverlay(HttpRequest request) async {
    final handler = cameraShowOverlayHandler;
    try {
      final map = await _readJsonBody(request);
      final enableRaw = map['enable'];
      final enable = enableRaw is num
          ? enableRaw.toInt()
          : int.tryParse(enableRaw?.toString() ?? '');
      if (enable != 0 && enable != 1) {
        await _writeJson(
          request,
          HttpStatus.badRequest,
          ApiResult.fail('invalid_show_overlay_request', code: 400),
        );
        return;
      }
      var x = (map['positionx'] as num?)?.toInt() ?? 10;
      var y = (map['positiony'] as num?)?.toInt() ?? 10;
      x = x.clamp(0, 384);
      y = y.clamp(0, 288);
      if (handler == null) {
        await _writeJson(
          request,
          HttpStatus.serviceUnavailable,
          ApiResult.fail('show_overlay_unavailable', code: 503),
        );
        return;
      }
      final result = await handler({
        'enable': enable,
        'positionx': x,
        'positiony': y,
      });
      if (!result.ok) {
        await _writeJson(
          request,
          result.httpStatus,
          ApiResult.fail(result.message, code: result.httpStatus),
        );
        return;
      }
      await _writeJson(
        request,
        HttpStatus.ok,
        ApiResult.ok(
          data: result.data ??
              {
                'enable': enable,
                'positionx': x,
                'positiony': y,
              },
        ),
      );
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.badRequest,
        ApiResult.fail('invalid_show_overlay_request', code: 400),
      );
    }
  }

  Future<void> _videoAiReplay(
    HttpRequest request,
    ProcessVideoRepository repo,
    String videoId,
  ) async {
    await repo.open();
    final row = await repo.findByVideoId(videoId);
    if (row == null) {
      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('video_not_found', code: 404),
      );
      return;
    }
    final source = File(row.videoPath);
    if (!await source.exists()) {
      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('video_not_found', code: 404),
      );
      return;
    }
    final cacheKey = ProcessVideoAiInferencePaths.cacheKey(row, source);
    final timelineFile = ProcessVideoAiInferencePaths.timelineJson(row, cacheKey);
    ProcessVideoAiTimeline? timeline =
        processVideoAiRegistry.peekByCacheKey(cacheKey)?.timeline;
    if (timeline == null || timeline.snapshotFrames().isEmpty) {
      timeline = await ProcessVideoAiTimelinePersistence.load(timelineFile);
    }
    if (timeline == null) {
      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('ai_replay_not_found', code: 404),
      );
      return;
    }
    final generatedAt = await timelineFile.exists()
        ? (await timelineFile.lastModified()).millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;
    await _writeJson(
      request,
      HttpStatus.ok,
      ApiResult.ok(
        data: ProcessVideoAiReplayJson.replayData(
          videoId: videoId,
          generatedAtMs: generatedAt,
          timeline: timeline,
        ),
      ),
    );
  }

  Future<void> _videoAiSse(
    HttpRequest request,
    ProcessVideoRepository repo,
    String videoId,
  ) async {
    await repo.open();
    final row = await repo.findByVideoId(videoId);
    if (row == null) {
      await _writeJson(
        request,
        HttpStatus.notFound,
        ApiResult.fail('video_not_found', code: 404),
      );
      return;
    }
    var available = false;
    final check = processVideoAiAvailable;
    if (check != null) {
      try {
        available = await check();
      } catch (_) {
        available = false;
      }
    } else {
      available = AiDaemonSupervisor.instance.isReady;
    }
    if (!available) {
      await _writePlain(
        request,
        HttpStatus.serviceUnavailable,
        'process_video_ai_unavailable',
      );
      return;
    }
    final source = File(row.videoPath);
    if (!await source.exists() || await source.length() <= 0) {
      await _writePlain(
        request,
        HttpStatus.serviceUnavailable,
        'process_video_ai_unavailable',
      );
      return;
    }
    final session = processVideoAiRegistry.acquire(
      record: row,
      sourceFile: source,
      holder: ProcessVideoAiHolder.http,
    );
    if (session == null) {
      await _writePlain(
        request,
        HttpStatus.serviceUnavailable,
        'process_video_ai_unavailable',
      );
      return;
    }
    if (!session.isRunning) {
      session.start();
    }
    final sub = session.acquireSseSubscriber();
    if (sub == null) {
      processVideoAiRegistry.release(session, ProcessVideoAiHolder.http);
      await _writePlain(
        request,
        HttpStatus.serviceUnavailable,
        'process_video_ai_unavailable',
      );
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      'text/event-stream; charset=utf-8',
    );
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.response.headers.set('X-Accel-Buffering', 'no');
    request.response.bufferOutput = false;

    var closed = false;
    var released = false;
    void releaseOnce() {
      if (released) {
        return;
      }
      released = true;
      sub.closeFromClient();
      processVideoAiRegistry.release(session, ProcessVideoAiHolder.http);
    }

    unawaited(request.response.done.then((_) {
      closed = true;
      releaseOnce();
    }));

    try {
      await for (final frame in sub.frames) {
        if (closed) {
          break;
        }
        request.response.add(frame);
        await request.response.flush();
      }
    } catch (e) {
      debugPrint('local-http: process video ai sse end: $e');
    } finally {
      releaseOnce();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleCameraAi(HttpRequest request) async {
    final check = cameraAiAvailable;
    var available = false;
    if (check != null) {
      try {
        available = await check();
      } catch (_) {
        available = false;
      }
    }
    if (!available) {
      await _writePlain(
        request,
        HttpStatus.serviceUnavailable,
        'camera_ai_unavailable',
      );
      return;
    }

    final sub = cameraAiPublisher.acquire();

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.set(
      HttpHeaders.contentTypeHeader,
      'text/event-stream; charset=utf-8',
    );
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.response.headers.set('X-Accel-Buffering', 'no');
    request.response.bufferOutput = false;

    var closed = false;
    unawaited(request.response.done.then((_) {
      closed = true;
      sub.closeFromClient();
    }));

    try {
      await for (final frame in sub.frames) {
        if (closed) {
          break;
        }
        request.response.add(frame);
        await request.response.flush();
      }
    } catch (e) {
      debugPrint('local-http: camera ai sse end: $e');
    } finally {
      sub.closeFromClient();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  // --- ADB -------------------------------------------------------------------

  Future<void> _handleAdb(HttpRequest request) async {
    final ssh = sshDebug;
    if (ssh == null) {
      await _writeJson(
        request,
        HttpStatus.serviceUnavailable,
        ApiResult.fail('adb_enable_failed', code: 503),
      );
      return;
    }
    try {
      await ssh.setEnabled(true);
      await _writeJson(request, HttpStatus.ok, ApiResult.ok());
    } catch (e) {
      await _writeJson(
        request,
        HttpStatus.serviceUnavailable,
        ApiResult.fail('adb_enable_failed', code: 503),
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

  Future<void> _writePlain(
    HttpRequest request,
    int status,
    String body,
  ) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.text;
    request.response.write(body);
    await request.response.close();
  }
}
