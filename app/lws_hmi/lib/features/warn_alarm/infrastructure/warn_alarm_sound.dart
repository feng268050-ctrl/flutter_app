import 'package:cyber_hal/output.dart';
import 'package:flutter/foundation.dart';

/// Warn alarm loop SFX (lws-ui SoundPool / remote mpg123 soft-V + end re-LOAD).
///
/// Policy:
/// - Loop while a warn dialog is visible for an alerting code
///   ([WarnAlarmController] drives start/stop via [ensurePlaying] / [stop]).
/// - Same [episodeCode] already sounding → return (no stop/restart), unless
///   the underlying loop process died ([MediaAudioController.hasActiveLoop]).
/// - In-flight [ensurePlaying] is invalidated by [stop] (generation bump) so a
///   late `LOAD` after dialog teardown cannot leave an orphan mpg123 loop.
/// - Loudness follows media [MediaAudioController.setVolumePercent].
final class WarnAlarmSound {
  WarnAlarmSound(this._audio);

  /// Bundled asset (lws-ui `R.raw.warn_mp3`).
  static const assetKey = 'assets/audio/warn_mp3.mp3';

  final MediaAudioController _audio;

  String? _episodeCode;
  bool _wantLoop = false;

  /// Bumped on every [stop] / [stopForEpisode] so a late [ensurePlaying] await
  /// can detect cancellation and re-issue [MediaAudioController.stop].
  int _stopGeneration = 0;

  String? get activeEpisodeCode => _episodeCode;

  bool get isActive => _wantLoop && _episodeCode != null;

  /// True when the HAL still has an armed warn loop but this facade is idle —
  /// e.g. stop raced ahead of a finishing [playLoopingAsset].
  ///
  /// Also true when **another** [WarnAlarmSound] on the same
  /// [MediaAudioController] owns the loop. Callers MUST NOT treat that as
  /// "safe to [stop]" unless they know this facade started the loop.
  bool get hasOrphanPlayback => !isActive && _audio.hasActiveLoop;

  /// Start / keep loop for [episodeCode] (dialog appear).
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
    final genAtStart = _stopGeneration;
    _episodeCode = episodeCode;
    _wantLoop = true;
    debugPrint('warn-sfx: ensurePlaying code=$episodeCode gen=$genAtStart');
    try {
      await _audio.playLoopingAsset(assetKey);
    } catch (e) {
      debugPrint('warn-sfx: play failed: $e');
    }
    // Dialog may have closed (stop) while LOAD was in flight — disarm again.
    if (_stopGeneration != genAtStart ||
        !_wantLoop ||
        _episodeCode != episodeCode) {
      debugPrint(
        'warn-sfx: stale play discarded code=$episodeCode '
        'genNow=$_stopGeneration want=$_wantLoop',
      );
      try {
        await _audio.stop();
      } catch (e) {
        debugPrint('warn-sfx: stale-play stop failed: $e');
      }
    }
  }

  /// Stop when [episodeCode] is cleared (or [episodeCode] is null = stop any).
  ///
  /// No-op if a *different* code still owns the loop (code-change handoff).
  /// Still stops when flags are idle but [hasOrphanPlayback] (race cleanup).
  Future<void> stopForEpisode(String? episodeCode) async {
    if (episodeCode != null &&
        _episodeCode != null &&
        episodeCode != _episodeCode) {
      return;
    }
    final intentional = _wantLoop || _episodeCode != null;
    final orphan = _audio.hasActiveLoop;
    if (!intentional && !orphan) {
      return;
    }
    _wantLoop = false;
    _episodeCode = null;
    _stopGeneration++;
    debugPrint(
      'warn-sfx: stop gen=$_stopGeneration intentional=$intentional '
      'orphan=$orphan',
    );
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
