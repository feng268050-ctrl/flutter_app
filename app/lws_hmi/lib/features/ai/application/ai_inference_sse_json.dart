import 'dart:convert';

/// JSON payloads for AI inference SSE events (lws-ui `AiInferenceSseJson` parity).
final class AiInferenceSseJson {
  const AiInferenceSseJson._();

  static String idleData({
    required int timestampMs,
    required bool inferenceActive,
  }) =>
      jsonEncode(<String, Object?>{
        'timestampMs': timestampMs,
        'inferenceActive': inferenceActive,
      });

  static String startData({
    required String sessionId,
    required int timestampMs,
    required String source,
    required int samplingIntervalMs,
    int? imageWidth,
    int? imageHeight,
  }) {
    final root = <String, Object?>{
      'sessionId': sessionId,
      'timestampMs': timestampMs,
      'source': source,
      'samplingIntervalMs': samplingIntervalMs,
    };
    if (imageWidth != null && imageWidth > 0) {
      root['imageWidth'] = imageWidth;
    }
    if (imageHeight != null && imageHeight > 0) {
      root['imageHeight'] = imageHeight;
    }
    return jsonEncode(root);
  }

  static String stopData({
    required String sessionId,
    required int timestampMs,
    required String reason,
  }) =>
      jsonEncode(<String, Object?>{
        'sessionId': sessionId,
        'timestampMs': timestampMs,
        'reason': reason,
      });

  static String runningData({
    required int timestampMs,
    String? sessionId,
    required bool success,
    required int code,
    required int level,
    required String status,
    required String message,
    required int imageWidth,
    required int imageHeight,
    required String source,
    required List<Map<String, Object?>> boxes,
  }) {
    final root = <String, Object?>{
      'timestampMs': timestampMs,
      'success': success,
      'code': code,
      'level': level,
      'status': status,
      'message': message,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'source': source,
      'boxes': boxes,
    };
    if (sessionId != null && sessionId.isNotEmpty) {
      root['sessionId'] = sessionId;
    }
    return jsonEncode(root);
  }

  static String errorData({required int code, required String message}) =>
      jsonEncode(<String, Object?>{
        'code': code,
        'message': message,
      });
}

/// Session metadata for `event: start` replay to late subscribers.
final class AiInferenceSessionStart {
  const AiInferenceSessionStart({
    required this.sessionId,
    required this.source,
    required this.samplingIntervalMs,
    this.imageWidth,
    this.imageHeight,
  });

  final String sessionId;
  final String source;
  final int samplingIntervalMs;
  final int? imageWidth;
  final int? imageHeight;
}

/// One completed unified inference sample for `event: running`.
final class AiInferenceRunningSample {
  const AiInferenceRunningSample({
    required this.success,
    required this.code,
    required this.level,
    required this.status,
    required this.message,
    required this.imageWidth,
    required this.imageHeight,
    required this.source,
    required this.boxes,
  });

  final bool success;
  final int code;
  final int level;
  final String status;
  final String message;
  final int imageWidth;
  final int imageHeight;
  final String source;
  final List<Map<String, Object?>> boxes;
}
