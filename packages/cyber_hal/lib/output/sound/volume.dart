/// Volume / ALSA mixer + optional media playback.
///
/// Backend kind: OS component (`amixer`, `mpg123`; optional board helper).
/// Concrete Linux type: [LinuxMediaAudioController] (exported from `hal/output.dart`).
library;

export 'package:cyber_hal/src/output/media_audio_controller.dart';

/// Portable volume API (0–100 percent). Mute may be stubbed on Linux v1.
abstract class Volume {
  Future<int> getVolumePercent();

  Future<void> setVolumePercent(int percent);

  Future<bool> isMuted();

  Future<void> setMuted(bool muted);
}
