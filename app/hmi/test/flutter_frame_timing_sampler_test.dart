import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/flutter_frame_timing_sampler.dart';

void main() {
  const windowUs = 1000000; // 1s

  test('fpsFromTimestamps uses span between first and last', () {
    // 57 frames over exactly 1s → 56 intervals → 56 fps
    final ts = List<int>.generate(57, (i) => i * (1000000 ~/ 56));
    final fps = FlutterFrameTimingSampler.fpsFromTimestamps(ts, windowUs);
    expect(fps, closeTo(56.0, 0.5));
  });

  test('fpsFromTimestamps returns null for empty', () {
    expect(FlutterFrameTimingSampler.fpsFromTimestamps(const [], windowUs), isNull);
  });

  test('fpsFromTimestamps single sample is 1 / window', () {
    expect(
      FlutterFrameTimingSampler.fpsFromTimestamps(const [42], windowUs),
      closeTo(1.0, 0.01),
    );
  });
}
