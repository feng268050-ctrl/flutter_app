import 'dart:convert';
import 'dart:io';

import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';

/// Maps native lens_det summary + optional `target.json` into an SSE running sample.
final class OpencvStainDetectMapper {
  const OpencvStainDetectMapper();

  static const overlayStatus = 'STAIN_DETECT';
  static const markerRadiusPx = 24.0;
  static const liveSource = 'live_stain_detect';
  static const offlineSource = 'offline_stain_detect';

  AiInferenceRunningSample fromSummaryJson({
    required String summaryJson,
    required String source,
    required int imageWidth,
    required int imageHeight,
    List<Directory> searchRoots = const [],
  }) {
    return fromDetectResult(
      event: <String, dynamic>{
        'summaryJson': summaryJson,
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
      },
      source: source,
      searchRoots: searchRoots,
    );
  }

  AiInferenceRunningSample fromDetectResult({
    required Map<String, dynamic> event,
    required String source,
    List<Directory> searchRoots = const [],
  }) {
    final imageWidth = _asInt(event['imageWidth']) ?? 0;
    final imageHeight = _asInt(event['imageHeight']) ?? 0;
    final summaryRaw = event['summaryJson']?.toString() ?? '';
    final summary = _parseSummary(summaryRaw);
    if (!summary.ok) {
      return AiInferenceRunningSample(
        success: false,
        code: summary.code,
        level: -1,
        status: 'ERROR',
        message: summary.reason.isEmpty ? 'lens_det_failed' : summary.reason,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        source: source,
        boxes: const [],
      );
    }
    final target = _resolveTarget(summary.files, searchRoots);
    if (target == null || !target.isValid) {
      return AiInferenceRunningSample(
        success: false,
        code: summary.code,
        level: -1,
        status: 'ERROR',
        message: 'invalid or missing target.json',
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        source: source,
        boxes: const [],
      );
    }
    return AiInferenceRunningSample(
      success: true,
      code: summary.code,
      level: 0,
      status: overlayStatus,
      message: target.name.isEmpty ? 'target' : target.name,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      source: source,
      boxes: [_boxFromTarget(target, imageWidth, imageHeight)],
    );
  }

  _Summary _parseSummary(String raw) {
    if (raw.trim().isEmpty) {
      return const _Summary(ok: false, code: -1, reason: 'empty summary json');
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const _Summary(ok: false, code: -1, reason: 'invalid summary json');
      }
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      final ok = map['ok'] == true;
      final code = _asInt(map['code']) ?? (ok ? 0 : -1);
      final reason = map['reason']?.toString() ?? '';
      final files = <String>[];
      final filesRaw = map['files'];
      if (filesRaw is List) {
        for (final item in filesRaw) {
          final s = item?.toString();
          if (s != null && s.isNotEmpty) {
            files.add(s);
          }
        }
      }
      return _Summary(ok: ok, code: code, reason: reason, files: files);
    } catch (_) {
      return const _Summary(ok: false, code: -1, reason: 'invalid summary json');
    }
  }

  _Target? _resolveTarget(List<String> files, List<Directory> searchRoots) {
    for (final path in files) {
      if (!(path.endsWith('/target.json') ||
          path.endsWith('\\target.json') ||
          path == 'target.json' ||
          path.endsWith('target.json'))) {
        continue;
      }
      final direct = File(path);
      if (direct.existsSync()) {
        return _parseTargetFile(direct);
      }
      if (direct.isAbsolute) {
        continue;
      }
      for (final root in searchRoots) {
        final under = File('${root.path}/$path');
        if (under.existsSync()) {
          return _parseTargetFile(under);
        }
      }
    }
    return null;
  }

  _Target _parseTargetFile(File file) {
    try {
      final raw = file.readAsStringSync();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return _Target.invalid();
      }
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      return _Target(
        name: map['name']?.toString() ?? 'target',
        x: _asDouble(map['x']) ?? double.nan,
        y: _asDouble(map['y']) ?? double.nan,
        bboxX: _asInt(map['bbox_x']) ?? 0,
        bboxY: _asInt(map['bbox_y']) ?? 0,
        width: _asInt(map['w']) ?? 0,
        height: _asInt(map['h']) ?? 0,
      );
    } catch (_) {
      return _Target.invalid();
    }
  }

  Map<String, Object?> _boxFromTarget(
    _Target target,
    int imageWidth,
    int imageHeight,
  ) {
    late final double x1;
    late final double y1;
    late final double x2;
    late final double y2;
    if (target.width > 0 && target.height > 0) {
      x1 = target.bboxX.toDouble();
      y1 = target.bboxY.toDouble();
      x2 = (target.bboxX + target.width).toDouble();
      y2 = (target.bboxY + target.height).toDouble();
    } else {
      final cx = target.x;
      final cy = target.y;
      x1 = cx - markerRadiusPx;
      y1 = cy - markerRadiusPx;
      x2 = cx + markerRadiusPx;
      y2 = cy + markerRadiusPx;
    }
    return <String, Object?>{
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'classId': 0,
      'label': 'contamination',
      'score': 1.0,
    };
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static double? _asDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }
}

final class _Summary {
  const _Summary({
    required this.ok,
    required this.code,
    this.reason = '',
    this.files = const [],
  });

  final bool ok;
  final int code;
  final String reason;
  final List<String> files;
}

final class _Target {
  const _Target({
    required this.name,
    required this.x,
    required this.y,
    required this.bboxX,
    required this.bboxY,
    required this.width,
    required this.height,
  });

  factory _Target.invalid() => const _Target(
        name: '',
        x: double.nan,
        y: double.nan,
        bboxX: 0,
        bboxY: 0,
        width: 0,
        height: 0,
      );

  final String name;
  final double x;
  final double y;
  final int bboxX;
  final int bboxY;
  final int width;
  final int height;

  bool get isValid => x.isFinite && y.isFinite;
}
