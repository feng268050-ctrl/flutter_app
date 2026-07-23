import 'package:cyber_hal/output/sound/button_feedback.dart';
import 'package:cyber_hal/src/output/sound/media_audio_controller.dart';

/// In-memory ButtonFeedback for host tests / sim.
final class StubButtonFeedback implements ButtonFeedback {
  StubButtonFeedback({
    MediaAudioController? mediaAudio,
    String initialAssetKey = '',
  })  : _mediaAudio = mediaAudio,
        _assetKey = initialAssetKey;

  final MediaAudioController? _mediaAudio;
  String _assetKey;
  int playCount = 0;
  String? lastPlayedAsset;

  @override
  String get assetKey => _assetKey;

  @override
  String warmRead() => _assetKey;

  @override
  Future<String> getAssetKey() async => _assetKey;

  @override
  Future<void> setAssetKey(String assetKey) async {
    _assetKey = assetKey.trim();
  }

  @override
  Future<void> play() async {
    playCount++;
    lastPlayedAsset = _assetKey;
    final audio = _mediaAudio;
    if (audio != null && _assetKey.isNotEmpty) {
      await audio.playOneShotAsset(_assetKey);
    }
  }

  @override
  Future<void> dispose() async {}
}
