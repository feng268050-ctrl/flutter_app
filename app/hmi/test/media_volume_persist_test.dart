import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/audio/linux_media_audio_controller.dart';

void main() {
  test('setVolumePercent persists media-volume preference', () async {
    final tmp = await Directory.systemTemp.createTemp('lws-vol-');
    addTearDown(() => tmp.delete(recursive: true));

    final pref = File('${tmp.path}/media-volume');
    final audio = LinuxMediaAudioController(
      cacheDir: '${tmp.path}/audio',
      volumePreferencePath: pref.path,
      // Missing amixer → soft-fail apply; persist must still succeed.
      amixerBinary: '${tmp.path}/no-amixer',
    );

    await audio.setVolumePercent(33);
    expect(await pref.exists(), isTrue);
    expect((await pref.readAsString()).trim(), '33');

    final audio2 = LinuxMediaAudioController(
      cacheDir: '${tmp.path}/audio',
      volumePreferencePath: pref.path,
      amixerBinary: '${tmp.path}/no-amixer',
    );
    expect(await audio2.getVolumePercent(), 33);
  });
}
