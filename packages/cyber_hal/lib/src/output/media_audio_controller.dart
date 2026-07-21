/// Reusable media playback + volume API (Linux ALSA now; Android later).
abstract class MediaAudioController {
  /// Bundled demo track (lws-ui `shanghai_tan.mp3`).
  static const shanghaiTanAsset = 'assets/audio/shanghai_tan.mp3';

  bool get isPlaying;

  /// Dedicated looping warn stream is running (SoundPool stream id ≠ 0).
  bool get hasActiveLoop;

  /// Emits whenever playback becomes active/idle (track end, stop, play).
  Stream<bool> get playing;

  Future<void> playAsset(String assetKey);

  /// Loop [assetKey] until [stop] (warn / alarm steady-state).
  ///
  /// Linux: sticky remote `mpg123 -R` + LOAD, re-LOAD on track end while armed
  /// (remote ignores `--loop`; same soft-V as [playOneShotAsset]). Android
  /// SoundPool `loop=-1`. Same asset already armed → volume only (no restart
  /// on repeat triggers). Click oneshot skipped while warn loop is armed.
  Future<void> playLoopingAsset(String assetKey);

  /// Short UI SFX (click). Uses a sticky mpg123 remote session when available.
  Future<void> playOneShotAsset(String assetKey);

  /// Open ALSA route + sticky mpg123 early so the first UI click is low-latency.
  Future<void> warmClickSession();

  Future<void> stop();

  Future<void> setVolumePercent(int percent);

  Future<int> getVolumePercent();

  Future<void> dispose();
}
