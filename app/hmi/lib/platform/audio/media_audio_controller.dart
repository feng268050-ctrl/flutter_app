/// Reusable media playback + volume API (Linux ALSA now; Android later).
abstract class MediaAudioController {
  /// Bundled demo track (lws-ui `shanghai_tan.mp3`).
  static const shanghaiTanAsset = 'assets/audio/shanghai_tan.mp3';

  bool get isPlaying;

  /// Emits whenever playback becomes active/idle (track end, stop, play).
  Stream<bool> get playing;

  Future<void> playAsset(String assetKey);

  Future<void> stop();

  Future<void> setVolumePercent(int percent);

  Future<int> getVolumePercent();

  Future<void> dispose();
}
