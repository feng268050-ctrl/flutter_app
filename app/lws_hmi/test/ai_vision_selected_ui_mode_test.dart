import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/ai_vision_selected_ui_mode.dart';

void main() {
  test('AiVisionSelectedUiMode covers lws-ui states', () {
    expect(AiVisionSelectedUiMode.values, containsAll([
      AiVisionSelectedUiMode.liveNoVideo,
      AiVisionSelectedUiMode.idleReadyToDetect,
      AiVisionSelectedUiMode.idleDetectionComplete,
      AiVisionSelectedUiMode.playback,
    ]));
  });
}
