import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_video/application/process_video_uploading_ws_throttle.dart';

void main() {
  test('WsThrottle emits on first, +5%, and 2s wall', () {
    final t = ProcessVideoUploadingWsThrottle();
    expect(t.shouldEmit(0), isTrue);
    expect(t.shouldEmit(1), isFalse);
    expect(t.shouldEmit(4), isFalse);
    expect(t.shouldEmit(5), isTrue);
    expect(t.shouldEmit(7), isFalse);
    expect(t.shouldEmit(10), isTrue);
  });
}
