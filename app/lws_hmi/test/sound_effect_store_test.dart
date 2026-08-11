import 'dart:typed_data';

import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';

void main() {
  Future<Uint8List> fakeLoad(String _) async => Uint8List.fromList([1, 2, 3]);

  test('clampIndex bounds to 0..2', () {
    expect(SoundEffectStore.clampIndex(null), 0);
    expect(SoundEffectStore.clampIndex(-1), 0);
    expect(SoundEffectStore.clampIndex(0), 0);
    expect(SoundEffectStore.clampIndex(2), 2);
    expect(SoundEffectStore.clampIndex(3), 0);
  });

  test('selectIndex installs shared path and warmRead matches basename', () async {
    final feedback = StubButtonFeedback();
    final store = SoundEffectStore(feedback: feedback, loadAsset: fakeLoad);
    await store.selectIndex(2);
    expect(store.index, 2);
    expect(feedback.assetKey, endsWith('click_effect_3.mp3'));
    expect(feedback.installed[feedback.assetKey], isNotNull);

    final again = SoundEffectStore(
      feedback: StubButtonFeedback(initialAssetKey: feedback.assetKey),
      loadAsset: fakeLoad,
    );
    again.warmRead();
    expect(again.index, 2);
  });
}
