/// Reusable media playback + volume API (Linux ALSA now; Android later).
abstract class MediaAudioController {
  /// Bundled demo track (lws-ui `shanghai_tan.mp3`).
  static const shanghaiTanAsset = 'assets/audio/shanghai_tan.mp3';

  bool get isPlaying;

  /// Emits whenever playback becomes active/idle (track end, stop, play).
  Stream<bool> get playing;

  Future<void> playAsset(String assetKey);

  /// Short UI SFX (click). Uses a sticky mpg123 remote session when available.
  Future<void> playOneShotAsset(String assetKey);

  /// Open ALSA route + sticky mpg123 early so the first UI click is low-latency.
  Future<void> warmClickSession();

  Future<void> stop();

  Future<void> setVolumePercent(int percent);

  Future<int> getVolumePercent();

  Future<void> dispose();
}
