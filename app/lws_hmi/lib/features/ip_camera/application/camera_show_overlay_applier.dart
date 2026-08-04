import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_time_request.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_video_overlay_editor.dart';

/// Validated OSD params for [CameraShowOverlayApplier.apply].
final class CameraShowOverlayParams {
  const CameraShowOverlayParams({
    required this.enable,
    required this.positionX,
    required this.positionY,
  });

  final int enable;
  final int positionX;
  final int positionY;

  static const defaultPosition = 10;
  static const minX = 0;
  static const maxX = 384;
  static const minY = 0;
  static const maxY = 288;
  static const maxYWhenEnabled =
      maxY - CameraVideoOverlayEditor.nameOverlayYOffset;

  /// Parses and validates; returns null when invalid.
  static CameraShowOverlayParams? tryParse({
    required Object? enableRaw,
    Object? positionXRaw,
    Object? positionYRaw,
  }) {
    final enable = enableRaw is num
        ? enableRaw.toInt()
        : int.tryParse(enableRaw?.toString() ?? '');
    if (enable != 0 && enable != 1) {
      return null;
    }
    final x = _readPosition(
      positionXRaw,
      defaultValue: defaultPosition,
      min: minX,
      max: maxX,
    );
    if (x == null) {
      return null;
    }
    final yMax = enable == 1 ? maxYWhenEnabled : maxY;
    final y = _readPosition(
      positionYRaw,
      defaultValue: defaultPosition,
      min: minY,
      max: yMax,
    );
    if (y == null) {
      return null;
    }
    return CameraShowOverlayParams(
      enable: enable!,
      positionX: x,
      positionY: y,
    );
  }

  static int? _readPosition(
    Object? raw, {
    required int defaultValue,
    required int min,
    required int max,
  }) {
    if (raw == null) {
      return defaultValue;
    }
    final value = raw is num ? raw.toInt() : int.tryParse(raw.toString());
    if (value == null || value < min || value > max) {
      return null;
    }
    return value;
  }
}

/// Result of one OSD apply (Settings dialog or LAN HTTP).
final class CameraShowOverlayResult {
  const CameraShowOverlayResult({
    required this.ok,
    this.httpStatus = 200,
    this.message = 'ok',
    this.enable,
    this.positionX,
    this.positionY,
    this.machineModel,
  });

  final bool ok;
  final int httpStatus;
  final String message;
  final int? enable;
  final int? positionX;
  final int? positionY;
  final String? machineModel;

  Map<String, Object?> dataMap() {
    final map = <String, Object?>{};
    if (enable != null) map['enable'] = enable;
    if (positionX != null) map['positionx'] = positionX;
    if (positionY != null) map['positiony'] = positionY;
    if (machineModel != null) map['machineModel'] = machineModel;
    if (enable == 1 && positionY != null) {
      map['nameoverlayy'] =
          positionY! + CameraVideoOverlayEditor.nameOverlayYOffset;
    }
    return map;
  }

  static CameraShowOverlayResult success({
    required int enable,
    required int positionX,
    required int positionY,
    required String machineModel,
  }) =>
      CameraShowOverlayResult(
        ok: true,
        enable: enable,
        positionX: positionX,
        positionY: positionY,
        machineModel: machineModel,
      );

  static CameraShowOverlayResult fail(
    String message, {
    int httpStatus = 503,
    int? enable,
    int? positionX,
    int? positionY,
    String? machineModel,
  }) =>
      CameraShowOverlayResult(
        ok: false,
        httpStatus: httpStatus,
        message: message,
        enable: enable,
        positionX: positionX,
        positionY: positionY,
        machineModel: machineModel,
      );
}

/// Minimal HTTP surface for camera OSD (injectable in tests).
abstract interface class CameraOsdHttpClient {
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  });

  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  });

  void close();
}

final class CameraOsdHttpResponse {
  const CameraOsdHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// In-process HTTP client for camera OSD (curl / OkHttp wire shape).
///
/// Uses a single [Socket] write for the full request (headers + body). Dart's
/// [HttpClient] flushes headers before the body; this MJPG-Streamer firmware
/// often applies empty PUT bodies as `errCode:200` when the JSON arrives in a
/// later TCP segment — small `showtime` bodies may work while larger
/// `overlays` PUTs silently no-op.
final class DartCameraOsdHttpClient implements CameraOsdHttpClient {
  DartCameraOsdHttpClient({
    Duration timeout = const Duration(seconds: 8),
    Future<Socket> Function(String host, int port, {Duration? timeout})?
        connect,
  })  : _timeout = timeout,
        _connect = connect ??
            ((host, port, {Duration? timeout}) => Socket.connect(
                  host,
                  port,
                  timeout: timeout,
                ));

  final Duration _timeout;
  final Future<Socket> Function(String host, int port, {Duration? timeout})
      _connect;

  @override
  Future<CameraOsdHttpResponse> get(
    Uri uri, {
    required String authorization,
  }) {
    return _request(
      method: 'GET',
      uri: uri,
      authorization: authorization,
    );
  }

  @override
  Future<CameraOsdHttpResponse> put(
    Uri uri, {
    required String authorization,
    Object? body,
  }) {
    final bytes = body == null ? null : utf8.encode(jsonEncode(body));
    return _request(
      method: 'PUT',
      uri: uri,
      authorization: authorization,
      body: bytes,
      forceEmptyBody: body == null,
    );
  }

  Future<CameraOsdHttpResponse> _request({
    required String method,
    required Uri uri,
    required String authorization,
    List<int>? body,
    bool forceEmptyBody = false,
  }) async {
    final path = _requestTarget(uri);
    final hostPort = uri.port == 0 ? uri.host : '${uri.host}:${uri.port}';
    final headerLines = <String>[
      '$method $path HTTP/1.1',
      'Host: $hostPort',
      'Authorization: $authorization',
      'Accept: */*',
      'Connection: close',
    ];
    if (body != null) {
      headerLines.add('Content-Type: application/json');
      headerLines.add('Content-Length: ${body.length}');
    } else if (forceEmptyBody) {
      headerLines.add('Content-Length: 0');
    }

    final builder = BytesBuilder(copy: false);
    builder.add(ascii.encode('${headerLines.join('\r\n')}\r\n\r\n'));
    if (body != null && body.isNotEmpty) {
      builder.add(body);
    }
    final packet = builder.takeBytes();
    debugPrint(
      'camera-show-overlay: $method $uri packet=${packet.length} '
      'body=${body?.length ?? 0}',
    );

    final socket = await _connect(
      uri.host,
      uri.port,
      timeout: _timeout,
    ).timeout(_timeout);
    try {
      socket.add(packet);
      await socket.flush().timeout(_timeout);
      final responseBytes = await socket.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      ).timeout(_timeout);
      final parsed = _parseHttpResponse(responseBytes);
      debugPrint(
        'camera-show-overlay: $method ${parsed.statusCode} '
        'bytes=${parsed.body.length}',
      );
      return parsed;
    } finally {
      socket.destroy();
    }
  }

  static String _requestTarget(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (!uri.hasQuery) {
      return path;
    }
    return '$path?${uri.query}';
  }

  static CameraOsdHttpResponse _parseHttpResponse(List<int> raw) {
    final text = utf8.decode(raw, allowMalformed: true);
    final split = text.indexOf('\r\n\r\n');
    if (split < 0) {
      return CameraOsdHttpResponse(statusCode: 0, body: text);
    }
    final head = text.substring(0, split);
    final body = text.substring(split + 4);
    final statusLine = head.split('\r\n').first;
    final parts = statusLine.split(' ');
    final code = parts.length >= 2 ? int.tryParse(parts[1]) ?? 0 : 0;
    return CameraOsdHttpResponse(statusCode: code, body: body);
  }

  @override
  void close() {}
}

/// Applies clock + NameOverlay OSD then saveConf (lws-ui coordinator parity).
///
/// Sequence: `PUT /System/showtime` → overlays GET/PUT → `PUT /System/saveConf`.
/// Does **not** call `PUT /System/time` (that is lws-ui record-time sync, not
/// part of show-overlay; enable=0 must only hide OSD via showtime enable=0).
final class CameraShowOverlayApplier {
  CameraShowOverlayApplier({
    CameraOsdHttpClient? httpClient,
    this.port = 9000,
    String authorization = '',
    DateTime Function()? now,
  })  : _http = httpClient ?? DartCameraOsdHttpClient(),
        _ownsHttp = httpClient == null,
        _authorization = authorization.isEmpty
            ? cameraHttpBasicAuthorization()
            : authorization,
        _now = now ?? DateTime.now;

  final CameraOsdHttpClient _http;
  final bool _ownsHttp;
  final int port;
  final String _authorization;
  final DateTime Function() _now;

  Future<void>? _tail;

  /// Serializes applies across Settings + LAN HTTP.
  Future<CameraShowOverlayResult> apply({
    required String cameraHost,
    required String machineModel,
    required CameraShowOverlayParams params,
  }) {
    final done = Completer<CameraShowOverlayResult>();
    final prev = _tail;
    _tail = () async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }
      try {
        done.complete(
          await _applyOnce(
            cameraHost: cameraHost,
            machineModel: machineModel,
            params: params,
          ),
        );
      } catch (e, st) {
        debugPrint('camera-show-overlay: $e\n$st');
        done.complete(
          CameraShowOverlayResult.fail(
            'camera_unreachable',
            enable: params.enable,
            positionX: params.positionX,
            positionY: params.positionY,
            machineModel: machineModel.trim(),
          ),
        );
      }
    }();
    return done.future;
  }

  Future<CameraShowOverlayResult> _applyOnce({
    required String cameraHost,
    required String machineModel,
    required CameraShowOverlayParams params,
  }) async {
    final host = cameraHost.trim();
    final model = machineModel.trim();
    if (host.isEmpty) {
      return CameraShowOverlayResult.fail(
        'camera_unreachable',
        enable: params.enable,
        positionX: params.positionX,
        positionY: params.positionY,
        machineModel: model,
      );
    }

    final showTime = CameraShowTimeRequest.create(
      enable: params.enable,
      positionX: params.positionX,
      positionY: params.positionY,
      fillNow: params.enable == 1,
      now: _now(),
    );

    final showTimeUri = _uri(host, 'System/showtime');
    final showTimeRes = await _http.put(
      showTimeUri,
      authorization: _authorization,
      body: showTime.toJson(),
    );
    final showTimeErr = _cameraResultError(showTimeRes, 'System/showtime');
    if (showTimeErr != null) {
      return CameraShowOverlayResult.fail(
        showTimeErr,
        httpStatus: _mapHttpStatus(showTimeRes.statusCode),
        enable: params.enable,
        positionX: params.positionX,
        positionY: params.positionY,
        machineModel: model,
      );
    }

    final overlayErr = await _applyNameOverlay(
      host: host,
      enable: params.enable,
      positionX: params.positionX,
      positionY: params.positionY,
      name: model,
    );
    if (overlayErr != null) {
      return CameraShowOverlayResult.fail(
        overlayErr,
        enable: params.enable,
        positionX: params.positionX,
        positionY: params.positionY,
        machineModel: model,
      );
    }

    final saveRes = await _http.put(
      _uri(host, 'System/saveConf'),
      authorization: _authorization,
    );
    final saveErr = _cameraResultError(saveRes, 'System/saveConf');
    if (saveErr != null) {
      return CameraShowOverlayResult.fail(
        saveErr,
        httpStatus: _mapHttpStatus(saveRes.statusCode),
        enable: params.enable,
        positionX: params.positionX,
        positionY: params.positionY,
        machineModel: model,
      );
    }

    return CameraShowOverlayResult.success(
      enable: params.enable,
      positionX: params.positionX,
      positionY: params.positionY,
      machineModel: model,
    );
  }

  Future<String?> _applyNameOverlay({
    required String host,
    required int enable,
    required int positionX,
    required int positionY,
    required String name,
  }) async {
    final path = CameraVideoOverlayEditor.overlaysChannel1Path;
    final overlaysUri = _uri(host, path);
    try {
      final getRes = await _http.get(
        overlaysUri,
        authorization: _authorization,
      );
      if (getRes.statusCode < 200 || getRes.statusCode >= 300) {
        return '${path}_http_${getRes.statusCode}';
      }
      final decoded = CameraVideoOverlayEditor.decodeJsonObject(getRes.body);
      final config = CameraVideoOverlayEditor.parseOverlayConfig(decoded);
      if (config == null) {
        return '${path}_invalid_body';
      }
      final updated = CameraVideoOverlayEditor.applyNameOverlay(
        config,
        enable: enable,
        positionX: positionX,
        positionY: positionY,
        name: name,
      );
      if (updated == null) {
        return '${path}_missing_name_overlay';
      }
      final putRes = await _http.put(
        overlaysUri,
        authorization: _authorization,
        body: updated,
      );
      return _cameraResultError(putRes, path);
    } catch (e, st) {
      debugPrint('camera-show-overlay name: $e\n$st');
      return '${path}_failed';
    }
  }

  Uri _uri(String host, String pathAndQuery) {
    final qIndex = pathAndQuery.indexOf('?');
    final path = qIndex >= 0 ? pathAndQuery.substring(0, qIndex) : pathAndQuery;
    final query = qIndex >= 0 ? pathAndQuery.substring(qIndex + 1) : null;
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: path.startsWith('/') ? path : '/$path',
      query: query,
    );
  }

  String? _cameraResultError(CameraOsdHttpResponse response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return '${path}_http_${response.statusCode}';
    }
    if (response.body.trim().isEmpty) {
      // saveConf may return empty on some firmwares; treat HTTP 2xx as ok.
      if (path == 'System/saveConf') {
        return null;
      }
      return '${path}_empty_body';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final errCode = decoded['errCode'];
      if (errCode == null) {
        return null;
      }
      final code = errCode is num
          ? errCode.toInt()
          : int.tryParse(errCode.toString());
      if (code == null || code == 200) {
        return null;
      }
      final message = decoded['errMessage']?.toString().trim() ?? '';
      if (message.isEmpty) {
        return '${path}_err_$code';
      }
      return '${path}_err_$code:$message';
    } catch (_) {
      return null;
    }
  }

  int _mapHttpStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return 200;
    }
    return statusCode > 0 ? statusCode : 503;
  }

  void dispose() {
    if (_ownsHttp) {
      _http.close();
    }
  }
}
