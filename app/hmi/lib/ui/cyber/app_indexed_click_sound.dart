import 'dart:async';

import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/sound_effect_store.dart';

/// App click backend via HAL [MediaAudioController.playOneShotAsset].
///
/// Mirrors lws-ui `GlobalSoundManager.playClickSound` + effect index selection.
/// Volume remains the ALSA mixer; oneshot goes through HAL so it shares the
/// mpg123 remote session when media already holds exclusive `plughw`.
class AppIndexedClickSound implements CyberClickSound {
  AppIndexedClickSound(
    this._store, {
    required MediaAudioController mediaAudio,
  }) : _mediaAudio = mediaAudio;

  final SoundEffectStore _store;
  final MediaAudioController _mediaAudio;

  static const debounceMs = 150;

  int _lastPlayUptimeMs = 0;

  SoundEffectStore get store => _store;

  /// Persist index and preview (lws-ui `openEffect`).
  Future<void> openEffect(int index) async {
    await _store.write(index);
    await playSample(_store.index);
  }

  Future<void> playSample(int index) async {
    final i = SoundEffectStore.clampIndex(index);
    await _playAssetKey(SoundEffectStore.assetKeys[i]);
  }

  @override
  Future<void> playClick() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayUptimeMs < debounceMs) {
      return;
    }
    _lastPlayUptimeMs = now;
    await _playAssetKey(_store.activeAssetKey);
  }

  Future<void> _playAssetKey(String assetKey) async {
    try {
      await _mediaAudio.playOneShotAsset(assetKey);
    } catch (e) {
      debugPrint('click-sfx: play failed: $e');
    }
  }
}
