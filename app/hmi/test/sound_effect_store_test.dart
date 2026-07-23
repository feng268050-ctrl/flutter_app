import 'package:cyber_hal/stub.dart';
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

  test('selectIndex and warmRead round-trip via ButtonFeedback', () async {
    final feedback = StubButtonFeedback();
    final store = SoundEffectStore(feedback: feedback);
    await store.selectIndex(2);
    expect(store.index, 2);
    expect(store.activeAssetKey, SoundEffectStore.assetKeys[2]);
    expect(feedback.assetKey, SoundEffectStore.assetKeys[2]);

    final again = SoundEffectStore(feedback: StubButtonFeedback(
      initialAssetKey: feedback.assetKey,
    ));
    again.warmRead();
    expect(again.index, 2);
  });
}
