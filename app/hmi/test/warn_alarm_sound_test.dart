import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';

void main() {
  test('ensurePlaying uses looping API and stop clears episode', () async {
    final audio = _FakeAudio();
    final sfx = WarnAlarmSound(audio);

    await sfx.ensurePlaying('C001');
    expect(sfx.isActive, isTrue);
    expect(audio.loopCalls, [WarnAlarmSound.assetKey]);

    await sfx.ensurePlaying('C001');
    expect(audio.loopCalls, hasLength(1), reason: 'same episode no-op');

    // Process died while episode still wanted → restart (no silent stuck).
    audio.killLoop();
    await sfx.ensurePlaying('C001');
    expect(audio.loopCalls, hasLength(2), reason: 'restart after loop death');

    await sfx.stopForEpisode('C001');
    expect(sfx.isActive, isFalse);
    expect(audio.stopCalls, 1);

    await sfx.dispose();
  });
}

final class _FakeAudio implements MediaAudioController {
  final _playingCtrl = StreamController<bool>.broadcast(sync: true);
  final loopCalls = <String>[];
  int stopCalls = 0;

  @override
  bool get isPlaying => false;

  @override
  Stream<bool> get playing => _playingCtrl.stream;

  @override
  Future<void> playAsset(String assetKey) async {}

  @override
  Future<void> playLoopingAsset(String assetKey) async {
    loopCalls.add(assetKey);
    _looping = true;
  }

  @override
  bool get hasActiveLoop => _looping;

  @override
  Future<void> playOneShotAsset(String assetKey) async {}

  @override
  Future<void> warmClickSession() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    _looping = false;
  }

  void killLoop() {
    _looping = false;
  }

  bool _looping = false;

  @override
  Future<void> setVolumePercent(int percent) async {}

  @override
  Future<int> getVolumePercent() async => 80;

  @override
  Future<void> dispose() async {
    await _playingCtrl.close();
  }
}
