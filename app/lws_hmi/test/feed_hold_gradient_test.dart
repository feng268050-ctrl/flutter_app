import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/feed_hold_gradient.dart';

void main() {
  group('FeedHoldGradient.midWidth', () {
    test('first paint is 18px then expands to full paint width', () {
      const paintW = 90.0;
      expect(
        FeedHoldGradient.midWidth(paintWidth: paintW, breathValue: 0),
        FeedHoldGradient.initialMidWidth,
      );
      expect(
        FeedHoldGradient.midWidth(paintWidth: paintW, breathValue: 1),
        paintW,
      );
      expect(
        FeedHoldGradient.midWidth(paintWidth: paintW, breathValue: 0.5),
        closeTo((18 + 90) / 2, 1e-9),
      );
    });

    test('Continuous Feed wider label still starts at 18px', () {
      const paintW = 180.0;
      expect(
        FeedHoldGradient.midWidth(paintWidth: paintW, breathValue: 0),
        18,
      );
      expect(
        FeedHoldGradient.midWidth(paintWidth: paintW, breathValue: 1),
        paintW,
      );
    });
  });

  group('FeedHoldGradient.shrinkRatio', () {
    test('18px mid on 90px paint ⇒ shrink 0.4', () {
      expect(
        FeedHoldGradient.shrinkRatio(paintWidth: 90, midWidth: 18),
        closeTo(0.4, 1e-9),
      );
      expect(
        FeedHoldGradient.shrinkRatio(paintWidth: 90, midWidth: 90),
        0,
      );
    });
  });

  test('hold expand duration matches 3s latch minus 500ms hold-to-run', () {
    expect(
      FeedHoldGradient.holdExpandDuration,
      DeviceControlTiming.wireFeedLatchDelay -
          DeviceControlTiming.wireHoldToRun,
    );
    expect(FeedHoldGradient.holdExpandDuration.inMilliseconds, 2500);
  });

  test('breathValue hold advances with wall clock', () {
    final start = DateTime(2026, 1, 1, 12, 0, 0);
    expect(
      FeedHoldGradient.breathValue(
        phase: 'holding',
        holdExpandStartedAt: start,
        latchBreathStartedAt: null,
        latchBreathPhaseOffset: 0,
        now: start.add(const Duration(milliseconds: 1250)),
      ),
      closeTo(0.5, 1e-9),
    );
  });

  test('gradient keeps transparent→mid→transparent with end-band stops', () {
    final g = FeedHoldGradient.gradient(
      mid: const Color(0xFFF46E01),
      shrinkRatio: 0.25,
    );
    expect(g.colors.length, 3);
    expect(g.colors[0].alpha, 0);
    expect(g.colors[1], const Color(0xFFF46E01));
    expect(g.colors[2].alpha, 0);
    expect(g.stops, [0.25, 0.5, 0.75]);
  });
}
