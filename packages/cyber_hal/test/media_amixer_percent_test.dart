import 'package:cyber_hal/src/output/sound/linux_media_audio_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('amixerHwPercent clamps 100 to 99 (rk809 DAC)', () {
    expect(LinuxMediaAudioController.amixerHwPercent(100), 99);
    expect(LinuxMediaAudioController.amixerHwPercent(101), 99);
    expect(LinuxMediaAudioController.amixerHwPercent(99), 99);
    expect(LinuxMediaAudioController.amixerHwPercent(80), 80);
    expect(LinuxMediaAudioController.amixerHwPercent(0), 0);
    expect(LinuxMediaAudioController.amixerHwPercent(-5), 0);
  });
}
