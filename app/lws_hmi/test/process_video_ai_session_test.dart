import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_hub.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/ai/application/process_video_ai_session.dart';

void main() {
  group('ProcessVideoAiSession.sampleMsForClockPosition', () {
    test('skips 0 and maps to interval grid', () {
      expect(ProcessVideoAiSession.sampleMsForClockPosition(0, 500), -1);
      expect(ProcessVideoAiSession.sampleMsForClockPosition(499, 500), -1);
      expect(ProcessVideoAiSession.sampleMsForClockPosition(500, 500), 500);
      expect(ProcessVideoAiSession.sampleMsForClockPosition(999, 500), 500);
      expect(ProcessVideoAiSession.sampleMsForClockPosition(1000, 500), 1000);
    });
  });

  group('AiInferenceSseHub media timeline', () {
    test('running uses contextMs not connection clock', () async {
      var mediaPos = 0;
      final hub = AiInferenceSseHub.forProcessVideo(
        mediaPositionMs: () => mediaPos,
      );
      final sub = hub.acquire();
      hub.notifySessionStarted(
        const AiInferenceSessionStart(
          sessionId: 's1',
          source: 'offline_stain_detect',
          samplingIntervalMs: 500,
        ),
      );
      hub.publishRunning(
        const AiInferenceRunningSample(
          success: true,
          code: 0,
          level: 0,
          status: 'STAIN_DETECT',
          message: 't',
          imageWidth: 100,
          imageHeight: 100,
          source: 'offline_stain_detect',
          boxes: [],
        ),
        contextMs: 1500,
        sessionId: 's1',
      );
      final frames = <String>[];
      await for (final bytes in sub.frames.timeout(const Duration(milliseconds: 50), onTimeout: (s) {
        s.close();
      })) {
        frames.add(String.fromCharCodes(bytes));
        if (frames.length >= 3) {
          break;
        }
      }
      expect(frames.any((f) => f.contains('event: running') && f.contains('"timestampMs":1500')), isTrue);
      sub.closeFromClient();
    });
  });
}
