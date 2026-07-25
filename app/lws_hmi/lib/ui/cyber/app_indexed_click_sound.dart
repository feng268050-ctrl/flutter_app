import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';

/// App click backend: forwards to HAL [ButtonFeedback.play].
class AppIndexedClickSound implements CyberClickSound {
  AppIndexedClickSound(this._store);

  final SoundEffectStore _store;

  static const debounceMs = 150;

  int _lastPlayUptimeMs = 0;

  SoundEffectStore get store => _store;

  ButtonFeedback get feedback => _store.feedback;

  /// Persist asset + preview (lws-ui `openEffect`).
  Future<void> openEffect(int index) async {
    await _store.previewIndex(index);
  }

  @override
  Future<void> playClick() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayUptimeMs < debounceMs) {
      return;
    }
    _lastPlayUptimeMs = now;
    try {
      await _store.feedback.play();
    } catch (e) {
      debugPrint('click-sfx: play failed: $e');
    }
  }
}
