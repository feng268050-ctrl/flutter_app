import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// On-disk paths for process-video AI timeline artifacts.
final class ProcessVideoAiInferencePaths {
  const ProcessVideoAiInferencePaths._();

  static const sampleIntervalMs = 500;

  static String cacheKey(ProcessVideoRecord record, File sourceFile) {
    final raw = '${record.id ?? 0}'
        '|${record.videoId}'
        '|${sourceFile.absolute.path}'
        '|${sourceFile.lengthSync()}'
        '|${sourceFile.lastModifiedSync().millisecondsSinceEpoch}'
        '|$sampleIntervalMs';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String ownerSegment(ProcessVideoRecord record) {
    if (record.id != null && record.id! > 0) {
      return '${record.id}';
    }
    final id = record.videoId.trim();
    return id.isEmpty ? 'unknown' : id;
  }

  static File timelineJson(ProcessVideoRecord record, String cacheKey) {
    final owner = ownerSegment(record);
    final dir = Directory(
      '${OsPaths.varHmi}/ai-vision-inference-videos/$owner',
    );
    return File(
      '${dir.path}/ai-vision-inference-$owner-$cacheKey.timeline.json',
    );
  }
}

/// One timeline sample (SSE running-row shape + media time).
final class ProcessVideoAiTimelineFrame {
  const ProcessVideoAiTimelineFrame({
    required this.timeMs,
    required this.sample,
  });

  final int timeMs;
  final AiInferenceRunningSample sample;

  Map<String, Object?> toRunningJson() => <String, Object?>{
        'timestampMs': timeMs,
        'success': sample.success,
        'code': sample.code,
        'level': sample.level,
        'status': sample.status,
        'message': sample.message,
        'imageWidth': sample.imageWidth,
        'imageHeight': sample.imageHeight,
        'source': sample.source,
        'boxes': sample.boxes,
      };

  static ProcessVideoAiTimelineFrame? fromJson(Map<String, dynamic> json) {
    final timeMs = _asInt(json['timestampMs']) ?? _asInt(json['timeMs']);
    if (timeMs == null) {
      return null;
    }
    final boxesRaw = json['boxes'];
    final boxes = <Map<String, Object?>>[];
    if (boxesRaw is List) {
      for (final b in boxesRaw) {
        if (b is Map) {
          boxes.add(b.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }
    return ProcessVideoAiTimelineFrame(
      timeMs: timeMs,
      sample: AiInferenceRunningSample(
        success: json['success'] == true,
        code: _asInt(json['code']) ?? -1,
        level: _asInt(json['level']) ?? -1,
        status: json['status']?.toString() ?? 'ERROR',
        message: json['message']?.toString() ?? '',
        imageWidth: _asInt(json['imageWidth']) ?? 0,
        imageHeight: _asInt(json['imageHeight']) ?? 0,
        source: json['source']?.toString() ?? 'offline_stain_detect',
        boxes: boxes,
      ),
    );
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}

final class ProcessVideoAiTimeline {
  ProcessVideoAiTimeline({
    required this.cacheKey,
    required this.durationMs,
    required this.sampleIntervalMs,
  });

  final String cacheKey;
  final int durationMs;
  final int sampleIntervalMs;
  final List<ProcessVideoAiTimelineFrame> _frames = [];

  List<ProcessVideoAiTimelineFrame> snapshotFrames() =>
      List<ProcessVideoAiTimelineFrame>.unmodifiable(_frames);

  /// Latest frame at or before [positionMs] (lws-ui `findFrameAt`).
  ProcessVideoAiTimelineFrame? findFrameAt(int positionMs) {
    if (_frames.isEmpty) {
      return null;
    }
    ProcessVideoAiTimelineFrame selected = _frames.first;
    for (final frame in _frames) {
      if (frame.timeMs <= positionMs) {
        selected = frame;
      } else {
        break;
      }
    }
    return selected;
  }

  bool hasSampleAt(int sampleMs) {
    for (final f in _frames) {
      if (f.timeMs == sampleMs) {
        return true;
      }
    }
    return false;
  }

  void addFrame(ProcessVideoAiTimelineFrame frame) => _frames.add(frame);

  void clear() => _frames.clear();
}

final class ProcessVideoAiTimelinePersistence {
  const ProcessVideoAiTimelinePersistence._();

  static const formatVersion = 1;

  static Future<void> save(File file, ProcessVideoAiTimeline timeline) async {
    await file.parent.create(recursive: true);
    final frames = timeline.snapshotFrames().map((f) => f.toRunningJson()).toList();
    final root = <String, Object?>{
      'formatVersion': formatVersion,
      'cacheKey': timeline.cacheKey,
      'durationMs': timeline.durationMs,
      'sampleIntervalMs': timeline.sampleIntervalMs,
      'frames': frames,
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(root));
  }

  static Future<ProcessVideoAiTimeline?> load(File file) async {
    if (!await file.exists() || await file.length() <= 0) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      final cacheKey = map['cacheKey']?.toString() ?? '';
      final durationMs = ProcessVideoAiTimelineFrame._asInt(map['durationMs']) ?? 0;
      final interval = ProcessVideoAiTimelineFrame._asInt(map['sampleIntervalMs']) ??
          ProcessVideoAiInferencePaths.sampleIntervalMs;
      final timeline = ProcessVideoAiTimeline(
        cacheKey: cacheKey,
        durationMs: durationMs,
        sampleIntervalMs: interval > 0 ? interval : ProcessVideoAiInferencePaths.sampleIntervalMs,
      );
      final framesRaw = map['frames'];
      if (framesRaw is List) {
        for (final item in framesRaw) {
          if (item is Map) {
            final frame = ProcessVideoAiTimelineFrame.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            );
            if (frame != null) {
              timeline.addFrame(frame);
            }
          }
        }
      }
      return timeline;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasReplayData(File file) async {
    final loaded = await load(file);
    return loaded != null;
  }
}

final class ProcessVideoAiReplayJson {
  const ProcessVideoAiReplayJson._();

  static const version = '1';

  static Map<String, Object?> replayData({
    required String videoId,
    required int generatedAtMs,
    required ProcessVideoAiTimeline timeline,
  }) =>
      <String, Object?>{
        'version': version,
        'videoId': videoId,
        'generatedAtMs': generatedAtMs,
        'frames': timeline.snapshotFrames().map((f) => f.toRunningJson()).toList(),
      };
}
