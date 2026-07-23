import 'package:flutter/foundation.dart';
import 'package:cyber_hal/output/sound/button_feedback.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/src/output/sound/media_audio_controller.dart';

/// Linux ButtonFeedback: persist asset key in [OutputPrefs.soundConf] + play via media.
final class LinuxButtonFeedback implements ButtonFeedback {
  LinuxButtonFeedback({
    required MediaAudioController mediaAudio,
    this.preferencePath = OutputPrefs.soundConf,
    String initialAssetKey = '',
  })  : _mediaAudio = mediaAudio,
        _assetKey = initialAssetKey;

  final MediaAudioController _mediaAudio;
  final String preferencePath;

  String _assetKey;
  bool _warmed = false;

  @override
  String get assetKey => _assetKey;

  @override
  String warmRead() {
    if (_warmed) {
      return _assetKey;
    }
    try {
      final map = readKeyValueConfFileSync(preferencePath);
      _assetKey = (map[OutputPrefs.keyButtonFeedback] ?? '').trim();
    } catch (e) {
      debugPrint('button-feedback: warmRead failed: $e');
    }
    _warmed = true;
    return _assetKey;
  }

  @override
  Future<String> getAssetKey() async {
    if (_warmed) {
      return _assetKey;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      _assetKey = (map[OutputPrefs.keyButtonFeedback] ?? '').trim();
    } catch (e) {
      debugPrint('button-feedback: read failed: $e');
    }
    _warmed = true;
    return _assetKey;
  }

  @override
  Future<void> setAssetKey(String assetKey) async {
    _assetKey = assetKey.trim();
    _warmed = true;
    await upsertKeyValueConfFile(preferencePath, {
      OutputPrefs.keyButtonFeedback: _assetKey,
    });
  }

  @override
  Future<void> play() async {
    final key = _assetKey;
    if (key.isEmpty) {
      return;
    }
    try {
      await _mediaAudio.playOneShotAsset(key);
    } catch (e) {
      debugPrint('button-feedback: play failed: $e');
    }
  }

  @override
  Future<void> dispose() async {}
}
