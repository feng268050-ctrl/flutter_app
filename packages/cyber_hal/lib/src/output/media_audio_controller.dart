/// Reusable media playback + volume API (Linux ALSA now; Android later).
abstract class MediaAudioController {
  /// Bundled demo track (lws-ui `shanghai_tan.mp3`).
  static const shanghaiTanAsset = 'assets/audio/shanghai_tan.mp3';

  bool get isPlaying;

  /// Warn loop is armed on the sticky session (`_loopPath` / SoundPool stream).
  bool get hasActiveLoop;

  /// Emits whenever playback becomes active/idle (track end, stop, play).
  Stream<bool> get playing;

  Future<void> playAsset(String assetKey);

  /// Loop [assetKey] until [stop] (warn / alarm steady-state).
  ///
  /// Linux: sticky remote `mpg123 -R` + LOAD, re-LOAD on track end while armed
  /// (same soft-V as [playOneShotAsset]). Mutual exclusion: oneshot is skipped
  /// while the loop is armed; [stop] then oneshot for Confirm click.
  Future<void> playLoopingAsset(String assetKey);

  /// Short UI SFX (click). Sticky mpg123 remote session.
  ///
  /// Skipped while [hasActiveLoop] — click and warn must not share the pipe.
  Future<void> playOneShotAsset(String assetKey);

  /// Open ALSA route + sticky mpg123 early so the first UI click is low-latency.
  Future<void> warmClickSession();

  Future<void> stop();

  Future<void> setVolumePercent(int percent);

  Future<int> getVolumePercent();

  Future<void> dispose();
}
