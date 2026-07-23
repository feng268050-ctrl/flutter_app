import 'dart:async';
import 'package:cyber_hal/output.dart';

/// App catalog + façade for HAL [ButtonFeedback] click samples.
///
/// Effect labels/assets stay product-owned; persistence and playback are HAL.
final class SoundEffectStore {
  SoundEffectStore({required this.feedback});

  static const effectCount = 3;
  static const defaultIndex = 0;

  /// Asset keys aligned with lws-ui `GlobalSoundManager.CLICK_RAW` order.
  static const assetKeys = <String>[
    'assets/audio/click_effect_1.mp3', // click_mp3_2 → Effect 1
    'assets/audio/click_effect_2.mp3', // click_mp3 → Effect 2
    'assets/audio/click_effect_3.mp3', // click_mp3_1 → Effect 3
  ];

  static const labels = <String>['Effect 1', 'Effect 2', 'Effect 3'];

  final ButtonFeedback feedback;

  int get index {
    final key = feedback.assetKey;
    final i = assetKeys.indexOf(key);
    return i >= 0 ? i : defaultIndex;
  }

  String get activeAssetKey {
    final key = feedback.assetKey;
    return key.isNotEmpty ? key : assetKeys[defaultIndex];
  }

  static int clampIndex(int? value) {
    if (value == null || value < 0 || value >= effectCount) {
      return defaultIndex;
    }
    return value;
  }

  /// Ensure a default asset is selected after warm-read if pref empty.
  int warmRead() {
    feedback.warmRead();
    if (feedback.assetKey.isEmpty) {
      unawaited(feedback.setAssetKey(assetKeys[defaultIndex]));
      return defaultIndex;
    }
    return index;
  }

  Future<void> selectIndex(int index) async {
    final i = clampIndex(index);
    await feedback.setAssetKey(assetKeys[i]);
  }

  Future<void> previewIndex(int index) async {
    await selectIndex(index);
    await feedback.play();
  }
}
