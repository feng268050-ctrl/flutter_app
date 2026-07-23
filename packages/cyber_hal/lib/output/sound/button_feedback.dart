/// UI button / click sound feedback (selected asset + play via audio HAL).
///
/// Backend kind: OS preference file + media/audio controller.
/// Concrete Linux type: [LinuxButtonFeedback] (exported from `hal/output/sound.dart`).
///
/// Product Apps own the asset catalog / Settings UI; HAL owns persistence + playback.
library;

/// Portable button-feedback API.
abstract class ButtonFeedback {
  /// Active Flutter asset key (empty when unset).
  String get assetKey;

  /// Synchronous warm-read for App bootstrap.
  String warmRead();

  Future<String> getAssetKey();

  /// Persist the selected asset key (App UI chooses among product samples).
  Future<void> setAssetKey(String assetKey);

  /// Play the active asset via the injected media/audio HAL.
  Future<void> play();

  Future<void> dispose();
}
