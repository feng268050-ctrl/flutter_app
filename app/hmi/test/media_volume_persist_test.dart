import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/audio/linux_media_audio_controller.dart';

void main() {
  test('setVolumePercent persists via change-volume helper', () async {
    final tmp = await Directory.systemTemp.createTemp('lws-vol-');
    addTearDown(() => tmp.delete(recursive: true));

    final pref = File('${tmp.path}/media-volume');
    final audio = LinuxMediaAudioController(
      cacheDir: '${tmp.path}/audio',
      volumePreferencePath: pref.path,
      changeVolumeCommand: const <String>['change-volume'],
      amixerBinary: '${tmp.path}/no-amixer',
      runHelper: (exe, args) async {
        expect(exe, 'change-volume');
        expect(args, ['33']);
        await pref.writeAsString('${args.single}\n');
        return 0;
      },
    );

    await audio.setVolumePercent(33);
    expect(await pref.exists(), isTrue);
    expect((await pref.readAsString()).trim(), '33');

    final audio2 = LinuxMediaAudioController(
      cacheDir: '${tmp.path}/audio',
      volumePreferencePath: pref.path,
      amixerBinary: '${tmp.path}/no-amixer',
      changeVolumeCommand: const <String>[],
    );
    expect(await audio2.getVolumePercent(), 33);
  });
}
