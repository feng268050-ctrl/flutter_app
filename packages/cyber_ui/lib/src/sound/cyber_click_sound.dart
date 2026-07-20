/// Backend for short UI click SFX (App registers Linux/asset player).
abstract class CyberClickSound {
  /// Play a click; must not block the UI thread (fire-and-forget OK).
  Future<void> playClick();
}

/// Process-wide registry (lws-ui `FrostUiClickSoundRegistry` stand-in).
///
/// Unregistered → [playClick] is a no-op. Media **volume** stays in
/// `cyber_hal` / Settings — this registry only triggers short clips.
abstract final class CyberClickSoundRegistry {
  static CyberClickSound? _backend;

  static void register(CyberClickSound? backend) {
    _backend = backend;
  }

  static CyberClickSound? get current => _backend;

  /// Fire-and-forget; swallows errors so taps never hang on audio.
  static void playClick() {
    final backend = _backend;
    if (backend == null) {
      return;
    }
    // ignore: discarded_futures
    backend.playClick().catchError((_) {});
  }
}
