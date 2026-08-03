import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/ai/application/opencv_stain_detect_mapper.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// On-device AI Vision overlay state (lws-ui `bindDetectionOverlayHud` + boxes).
final class AiVisionOverlayState {
  const AiVisionOverlayState({
    this.hudStatus,
    this.hudDetail,
    this.boxes = const [],
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  static const idle = AiVisionOverlayState();

  /// Raw status token for `AI: %s` (e.g. `STAIN_DETECT`, `IDLE`). Null hides HUD status.
  final String? hudStatus;

  /// Optional second line; null hides detail (lws-ui stain path leaves this null).
  final String? hudDetail;

  /// Pixel-space boxes from SSE / timeline (`x1,y1,x2,y2`).
  final List<Map<String, Object?>> boxes;

  final int imageWidth;
  final int imageHeight;

  bool get hasHud =>
      (hudStatus != null && hudStatus!.trim().isNotEmpty) ||
      (hudDetail != null && hudDetail!.trim().isNotEmpty);

  bool get hasBoxes => boxes.isNotEmpty;

  /// Detect/Replay in progress before the first timeline sample arrives.
  factory AiVisionOverlayState.stainDetectActive({
    int imageWidth = 0,
    int imageHeight = 0,
  }) =>
      AiVisionOverlayState(
        hudStatus: OpencvStainDetectMapper.overlayStatus,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

  /// Selected-video idle cover: `AI: IDLE` only (no boxes).
  factory AiVisionOverlayState.selectedIdle(AppLocalizations l10n) =>
      AiVisionOverlayState(hudStatus: l10n.aiOverlayHudStatusIdle);

  /// Visual equality for overlay tick de-dupe (avoid rebuilding video).
  bool sameVisual(AiVisionOverlayState other) {
    if (hudStatus != other.hudStatus ||
        hudDetail != other.hudDetail ||
        imageWidth != other.imageWidth ||
        imageHeight != other.imageHeight ||
        boxes.length != other.boxes.length) {
      return false;
    }
    for (var i = 0; i < boxes.length; i++) {
      final a = boxes[i];
      final b = other.boxes[i];
      if (a['x1'] != b['x1'] ||
          a['y1'] != b['y1'] ||
          a['x2'] != b['x2'] ||
          a['y2'] != b['y2'] ||
          a['label'] != b['label']) {
        return false;
      }
    }
    return true;
  }

  /// Map a running sample the way `AiVisionFragment` binds stain/live HUD.
  factory AiVisionOverlayState.fromSample(AiInferenceRunningSample sample) {
    if (!sample.success || sample.boxes.isEmpty) {
      // No target is normal (OpenCV -3 / empty boxes). Keep STAIN_DETECT HUD;
      // do not hide the overlay or show ERROR for ordinary miss frames.
      if (_isStainDetectSample(sample)) {
        return AiVisionOverlayState.stainDetectActive(
          imageWidth: sample.imageWidth,
          imageHeight: sample.imageHeight,
        );
      }
      return AiVisionOverlayState(
        hudStatus: sample.status.trim().isEmpty ? null : sample.status.trim(),
        imageWidth: sample.imageWidth,
        imageHeight: sample.imageHeight,
      );
    }
    // Stain detect hit: status STAIN_DETECT, detail suppressed (message is target name).
    if (sample.status == OpencvStainDetectMapper.overlayStatus) {
      return AiVisionOverlayState(
        hudStatus: OpencvStainDetectMapper.overlayStatus,
        boxes: sample.boxes,
        imageWidth: sample.imageWidth,
        imageHeight: sample.imageHeight,
      );
    }
    final status = sample.status.trim();
    final message = sample.message.trim();
    final detail = (message.isEmpty ||
            status.isEmpty ||
            message.toLowerCase() == status.toLowerCase())
        ? null
        : message;
    return AiVisionOverlayState(
      hudStatus: status.isEmpty ? null : status,
      hudDetail: detail,
      boxes: sample.boxes,
      imageWidth: sample.imageWidth,
      imageHeight: sample.imageHeight,
    );
  }

  static bool _isStainDetectSample(AiInferenceRunningSample sample) {
    if (sample.source == OpencvStainDetectMapper.offlineSource ||
        sample.source == OpencvStainDetectMapper.liveSource) {
      return true;
    }
    final status = sample.status.trim();
    return status == OpencvStainDetectMapper.overlayStatus ||
        status == 'ERROR' ||
        status == 'CLEAN';
  }
}
