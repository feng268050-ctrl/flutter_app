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

  test('late playLoopingAsset after stop does not leave orphan loop', () async {
    final audio = _FakeAudio(delayLoop: const Duration(milliseconds: 40));
    final sfx = WarnAlarmSound(audio);

    final play = sfx.ensurePlaying('C001');
    // Close dialog before LOAD finishes (C001 flap teardown race).
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await sfx.stop();
    expect(sfx.isActive, isFalse);

    await play;
    expect(sfx.isActive, isFalse);
    expect(audio.hasActiveLoop, isFalse, reason: 'stale play must re-stop');
    expect(audio.stopCalls, greaterThanOrEqualTo(2));

    await sfx.dispose();
  });

  test('stop clears orphan HAL loop when facade already idle', () async {
    final audio = _FakeAudio();
    final sfx = WarnAlarmSound(audio);
    await sfx.ensurePlaying('C001');
    await sfx.stop();
    expect(sfx.isActive, isFalse);

    // Simulate race: HAL re-armed after facade cleared flags.
    audio.forceArmLoop();
    expect(sfx.hasOrphanPlayback, isTrue);

    await sfx.stop();
    expect(audio.hasActiveLoop, isFalse);
    expect(sfx.hasOrphanPlayback, isFalse);

    await sfx.dispose();
  });
}

final class _FakeAudio implements MediaAudioController {
  _FakeAudio({this.delayLoop});

  final Duration? delayLoop;
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
    final delay = delayLoop;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
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

  void forceArmLoop() {
    _looping = true;
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
