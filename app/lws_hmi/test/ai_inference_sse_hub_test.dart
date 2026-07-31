import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_hub.dart';
import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';
import 'package:lws_hmi/features/ai/application/camera_ai_http_publisher.dart';

void main() {
  group('AiInferenceSseHub', () {
    test('first event is idle with timestampMs 0', () async {
      final hub = AiInferenceSseHub(idleInterval: const Duration(hours: 1));
      addTearDown(hub.resetForTest);
      final sub = hub.acquire();
      final frame = await sub.frames.first;
      final text = utf8.decode(frame);
      expect(text, startsWith('event: idle\n'));
      final data = jsonDecode(text.split('\ndata: ').last.trim())
          as Map<String, dynamic>;
      expect(data['timestampMs'], 0);
      expect(data['inferenceActive'], isFalse);
      sub.closeFromClient();
    });

    test('running timestampMs is connection-relative', () async {
      var now = DateTime.fromMillisecondsSinceEpoch(1000000);
      final hub = AiInferenceSseHub(
        idleInterval: const Duration(hours: 1),
        now: () => now,
      );
      addTearDown(hub.resetForTest);
      hub.notifySessionStarted(
        const AiInferenceSessionStart(
          sessionId: 'sid',
          source: 'live_stain_detect',
          samplingIntervalMs: 500,
          imageWidth: 640,
          imageHeight: 480,
        ),
      );
      final sub = hub.acquire();
      // Drain idle + start replay.
      await sub.frames.first;
      await sub.frames.first;

      now = DateTime.fromMillisecondsSinceEpoch(1002500);
      hub.publishRunning(
        const AiInferenceRunningSample(
          success: true,
          code: 0,
          level: 0,
          status: 'STAIN_DETECT',
          message: 'ok',
          imageWidth: 640,
          imageHeight: 480,
          source: 'live_stain_detect',
          boxes: [],
        ),
      );
      final runningFrame = await sub.frames.first;
      final text = utf8.decode(runningFrame);
      expect(text, startsWith('event: running\n'));
      final data = jsonDecode(text.split('\ndata: ').last.trim())
          as Map<String, dynamic>;
      expect(data['timestampMs'], 2500);
      expect(data['sessionId'], 'sid');
      sub.closeFromClient();
    });
  });

  group('CameraAiHttpPublisher', () {
    test('lens_det detect_result maps to running', () async {
      final publisher = CameraAiHttpPublisher();
      addTearDown(publisher.resetForTest);
      publisher.ingestDaemonEvent({
        'type': 'session_start',
        'source': 'live_stain_detect',
        'samplingIntervalMs': 500,
      });
      final sub = publisher.acquire();
      await sub.frames.first; // idle
      await sub.frames.first; // start

      publisher.ingestDaemonEvent({
        'type': 'detect_result',
        'module': 'lens_det',
        'imageWidth': 100,
        'imageHeight': 80,
        'code': -5,
        'ok': false,
        'summaryJson': '{"ok":false,"code":-5,"reason":"too_dirty","files":[]}',
      });
      final running = await sub.frames.first;
      final text = utf8.decode(running);
      expect(text, startsWith('event: running\n'));
      final data = jsonDecode(text.split('\ndata: ').last.trim())
          as Map<String, dynamic>;
      expect(data['success'], isFalse);
      expect(data['source'], 'live_stain_detect');
      expect(data['boxes'], isEmpty);
      sub.closeFromClient();
    });
  });
}
