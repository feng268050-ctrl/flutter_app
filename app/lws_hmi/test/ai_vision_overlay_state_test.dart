import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/ai/application/opencv_stain_detect_mapper.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_timeline.dart';
import 'package:lws_hmi/features/monitor/presentation/ai_vision_overlay_state.dart';
import 'package:lws_hmi/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('selectedIdle is AI IDLE without boxes', () {
    final s = AiVisionOverlayState.selectedIdle(l10n);
    expect(s.hudStatus, l10n.aiOverlayHudStatusIdle);
    expect(s.hudDetail, isNull);
    expect(s.hasBoxes, isFalse);
  });

  test('stainDetectActive shows HUD without waiting for boxes', () {
    final s = AiVisionOverlayState.stainDetectActive();
    expect(s.hudStatus, 'STAIN_DETECT');
    expect(s.hasHud, isTrue);
    expect(s.hasBoxes, isFalse);
  });

  test('stain sample suppresses result detail', () {
    final sample = AiInferenceRunningSample(
      success: true,
      code: 0,
      level: 0,
      status: OpencvStainDetectMapper.overlayStatus,
      message: 'target',
      imageWidth: 1920,
      imageHeight: 1080,
      source: OpencvStainDetectMapper.offlineSource,
      boxes: const [
        {'x1': 10, 'y1': 20, 'x2': 30, 'y2': 40, 'label': 'contamination'},
      ],
    );
    final s = AiVisionOverlayState.fromSample(sample);
    expect(s.hudStatus, 'STAIN_DETECT');
    expect(s.hudDetail, isNull);
    expect(s.hasBoxes, isTrue);
  });

  test('findFrameAt returns latest frame at or before position', () {
    final timeline = ProcessVideoAiTimeline(
      cacheKey: 'k',
      durationMs: 1000,
      sampleIntervalMs: 100,
    );
    AiInferenceRunningSample sampleAt(int t) => AiInferenceRunningSample(
          success: true,
          code: 0,
          level: 0,
          status: OpencvStainDetectMapper.overlayStatus,
          message: 't$t',
          imageWidth: 100,
          imageHeight: 100,
          source: OpencvStainDetectMapper.offlineSource,
          boxes: const [],
        );
    timeline.addFrame(ProcessVideoAiTimelineFrame(
      timeMs: 0,
      sample: sampleAt(0),
    ));
    timeline.addFrame(ProcessVideoAiTimelineFrame(
      timeMs: 200,
      sample: sampleAt(200),
    ));
    timeline.addFrame(ProcessVideoAiTimelineFrame(
      timeMs: 400,
      sample: sampleAt(400),
    ));
    expect(timeline.findFrameAt(0)?.timeMs, 0);
    expect(timeline.findFrameAt(199)?.timeMs, 0);
    expect(timeline.findFrameAt(200)?.timeMs, 200);
    expect(timeline.findFrameAt(350)?.timeMs, 200);
    expect(timeline.findFrameAt(999)?.timeMs, 400);
  });
}
