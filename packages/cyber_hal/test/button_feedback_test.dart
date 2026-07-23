import 'dart:io';

import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/src/output/sound/linux_button_feedback.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMedia implements MediaAudioController {
  String? lastOneShot;

  @override
  bool get isPlaying => false;

  @override
  bool get hasActiveLoop => false;

  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Future<void> playAsset(String assetKey) async {}

  @override
  Future<void> playLoopingAsset(String assetKey) async {}

  @override
  Future<void> playOneShotAsset(String assetKey) async {
    lastOneShot = assetKey;
  }

  @override
  Future<void> warmClickSession() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolumePercent(int percent) async {}

  @override
  Future<int> getVolumePercent() async => 50;

  @override
  Future<void> dispose() async {}
}

void main() {
  test('LinuxButtonFeedback persists button_feedback in sound.conf', () async {
    final dir = await Directory.systemTemp.createTemp('btn-fb-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/sound.conf');
    await pref.writeAsString('volume=70\n');

    final media = _FakeMedia();
    final fb = LinuxButtonFeedback(
      mediaAudio: media,
      preferencePath: pref.path,
    );
    await fb.setAssetKey('assets/audio/click_effect_2.mp3');

    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyButtonFeedback], contains('click_effect_2'));
    expect(map[OutputPrefs.keyVolume], '70');

    final again = LinuxButtonFeedback(
      mediaAudio: media,
      preferencePath: pref.path,
    );
    expect(again.warmRead(), 'assets/audio/click_effect_2.mp3');
  });

  test('play delegates to media HAL', () async {
    final media = _FakeMedia();
    final fb = StubButtonFeedback(mediaAudio: media);
    await fb.setAssetKey('assets/audio/click_effect_3.mp3');
    await fb.play();
    expect(media.lastOneShot, 'assets/audio/click_effect_3.mp3');
  });
}
