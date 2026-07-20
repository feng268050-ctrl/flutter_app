import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';

void main() {
  test('clampIndex bounds to 0..2', () {
    expect(SoundEffectStore.clampIndex(null), 0);
    expect(SoundEffectStore.clampIndex(-1), 0);
    expect(SoundEffectStore.clampIndex(0), 0);
    expect(SoundEffectStore.clampIndex(2), 2);
    expect(SoundEffectStore.clampIndex(3), 0);
  });

  test('write and warmRead round-trip', () async {
    final dir = await Directory.systemTemp.createTemp('sfx-');
    final path = '${dir.path}/sound-effect';
    final store = SoundEffectStore(preferencePath: path);

    expect(store.warmRead(), 0);
    await store.write(2);
    expect(store.index, 2);

    final again = SoundEffectStore(preferencePath: path);
    expect(again.warmRead(), 2);
    expect(again.activeAssetKey, SoundEffectStore.assetKeys[2]);

    await dir.delete(recursive: true);
  });
}
