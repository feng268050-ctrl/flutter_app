import 'dart:io';
import 'dart:typed_data';

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
  test('installAndSelect copies sample next to sound.conf and persists path',
      () async {
    final dir = await Directory.systemTemp.createTemp('btn-fb-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/sound.conf');
    await pref.writeAsString('volume=70\n');

    final media = _FakeMedia();
    final fb = LinuxButtonFeedback(
      mediaAudio: media,
      preferencePath: pref.path,
    );
    final bytes = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final path = await fb.installAndSelect(
      bytes,
      fileName: 'click_effect_2.mp3',
    );

    expect(path, '${dir.path}/click_effect_2.mp3');
    expect(File(path).existsSync(), isTrue);
    expect(File(path).lengthSync(), 32);

    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyButtonFeedback], path);
    expect(map[OutputPrefs.keyVolume], '70');

    final again = LinuxButtonFeedback(
      mediaAudio: media,
      preferencePath: pref.path,
    );
    expect(again.warmRead(), path);
    expect(again.samplesDirectory, dir.path);

    await again.play();
    expect(media.lastOneShot, path);
  });

  test('listInstalledSamples returns mp3 files beside conf', () async {
    final dir = await Directory.systemTemp.createTemp('btn-list-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/sound.conf');
    await pref.writeAsString('volume=1\n');
    final fb = LinuxButtonFeedback(
      mediaAudio: _FakeMedia(),
      preferencePath: pref.path,
    );
    await fb.installSample(Uint8List.fromList([1]), fileName: 'a.mp3');
    await fb.installSample(Uint8List.fromList([2]), fileName: 'b.mp3');
    final listed = await fb.listInstalledSamples();
    expect(listed, [
      '${dir.path}/a.mp3',
      '${dir.path}/b.mp3',
    ]);
  });

  test('play delegates to media HAL', () async {
    final media = _FakeMedia();
    final fb = StubButtonFeedback(mediaAudio: media);
    await fb.installAndSelect(
      Uint8List.fromList([9]),
      fileName: 'click_effect_3.mp3',
    );
    await fb.play();
    expect(media.lastOneShot, endsWith('click_effect_3.mp3'));
  });

  test('sanitizeClickSampleFileName rejects path tricks', () {
    expect(sanitizeClickSampleFileName('click_effect_1.mp3'), 'click_effect_1.mp3');
    expect(
      () => sanitizeClickSampleFileName('../evil.mp3'),
      throwsArgumentError,
    );
  });
}
