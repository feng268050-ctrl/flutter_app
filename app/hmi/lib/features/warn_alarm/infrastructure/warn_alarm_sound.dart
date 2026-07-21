import 'package:cyber_hal/output.dart';
import 'package:flutter/foundation.dart';

/// Warn alarm loop SFX (lws-ui SoundPool / remote mpg123 soft-V + end re-LOAD).
///
/// Policy (listen continuity):
/// - While the same unresolved alarm code is active, the **player** keeps
///   looping (`playLoopingAsset` → remote LOAD, re-LOAD on track end).
/// - Same [episodeCode] already sounding → return (repeat triggers must not
///   stop/restart), unless the underlying loop process died.
/// - Start/stop only on **appear**, **code change**, or **clear** — not on
///   dialog confirm/dismiss.
/// - Loudness follows media [MediaAudioController.setVolumePercent].
final class WarnAlarmSound {
  WarnAlarmSound(this._audio);

  /// Bundled asset (lws-ui `R.raw.warn_mp3`).
  static const assetKey = 'assets/audio/warn_mp3.mp3';

  final MediaAudioController _audio;

  String? _episodeCode;
  bool _wantLoop = false;

  String? get activeEpisodeCode => _episodeCode;

  bool get isActive => _wantLoop && _episodeCode != null;

  /// Start / keep loop for [episodeCode] (appear or code-change).
  ///
  /// Same episodeCode already playing → return (no stop/restart), unless
  /// [MediaAudioController.hasActiveLoop] is false (process died → restart).
  Future<void> ensurePlaying(String episodeCode) async {
    if (episodeCode.isEmpty) {
      return;
    }
    if (_episodeCode == episodeCode && _wantLoop && _audio.hasActiveLoop) {
      return;
    }
    _episodeCode = episodeCode;
    _wantLoop = true;
    try {
      await _audio.playLoopingAsset(assetKey);
    } catch (e) {
      debugPrint('warn-sfx: play failed: $e');
    }
  }

  /// Stop when [episodeCode] is cleared (or [episodeCode] is null = stop any).
  ///
  /// No-op if a *different* code still owns the loop (code-change handoff).
  /// No-op when already idle (avoids 400ms poll spamming [MediaAudioController.stop]
  /// and racing the sticky mpg123 stdin).
  Future<void> stopForEpisode(String? episodeCode) async {
    if (episodeCode != null &&
        _episodeCode != null &&
        episodeCode != _episodeCode) {
      return;
    }
    if (!_wantLoop && _episodeCode == null) {
      return;
    }
    _wantLoop = false;
    _episodeCode = null;
    try {
      await _audio.stop();
    } catch (e) {
      debugPrint('warn-sfx: stop failed: $e');
    }
  }

  Future<void> stop() => stopForEpisode(null);

  Future<void> dispose() async {
    await stop();
  }
}
