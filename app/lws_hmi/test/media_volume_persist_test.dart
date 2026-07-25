import 'dart:io';

import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/audio/linux_media_audio_controller.dart';

void main() {
  test('setVolumePercent persists via change-volume helper', () async {
    final tmp = await Directory.systemTemp.createTemp('lws-vol-');
    addTearDown(() => tmp.delete(recursive: true));

    final pref = File('${tmp.path}/sound.conf');
    final audio = LinuxMediaAudioController(
      cacheDir: '${tmp.path}/audio',
      volumePreferencePath: pref.path,
      changeVolumeCommand: const <String>['change-volume'],
      amixerBinary: '${tmp.path}/no-amixer',
      runHelper: (exe, args) async {
        expect(exe, 'change-volume');
        expect(args, ['33']);
        await upsertKeyValueConfFile(pref.path, {
          OutputPrefs.keyVolume: args.single,
        });
        return 0;
      },
    );

    await audio.setVolumePercent(33);
    expect(await pref.exists(), isTrue);
    expect(parseKeyValueConf(await pref.readAsString())[OutputPrefs.keyVolume], '33');

    final audio2 = LinuxMediaAudioController(
      cacheDir: '${tmp.path}/audio',
      volumePreferencePath: pref.path,
      amixerBinary: '${tmp.path}/no-amixer',
      changeVolumeCommand: const <String>[],
    );
    expect(await audio2.getVolumePercent(), 33);
  });
}
