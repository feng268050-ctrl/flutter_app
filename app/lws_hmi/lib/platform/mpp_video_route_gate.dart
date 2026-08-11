import 'dart:async';

/// Serializes Rockchip MPP consumers (Flutter [VideoPlayer] + extract helpers).
///
/// eLinux file VOD / RTSP and `/usr/libexec/hmi/extract-video-frame` share one
/// MPP context. Overlapping **cover** extract + Videos VOD decode caused
/// `qtdemux` `Internal data stream error (-5)` a few seconds into playback.
///
/// - Pages: [beforeAcquire] before creating a decoder, [scheduleRelease] on leave.
/// - Cover / upload drain: [runExclusive] (waits while a decoder lease is held).
/// - AI offline samples: [runExclusive] with [waitForDecoder] false — Detect
///   intentionally samples while VOD plays; those stay serialized with each
///   other via the extract chain only.
abstract final class MppVideoRouteGate {
  static Future<void> _acquireLock = Future<void>.value();
  static Future<void> _extractChain = Future<void>.value();
  static Future<void> _releaseTail = Future<void>.value();

  static bool _held = false;
  static Completer<void>? _idle;

  /// Brief pause after extract / dispose so MPP buffer teardown can finish.
  static const Duration settle = Duration(milliseconds: 250);

  /// Wait until cover extracts / prior releases finish, then mark decoder held.
  ///
  /// Re-entrant while already holding (AI Vision select → ensure playback).
  static Future<void> beforeAcquire() async {
    if (_held) {
      return;
    }
    final acquired = Completer<void>();
    _acquireLock = _acquireLock.then((_) async {
      try {
        while (_held) {
          await (_idle?.future ?? Future<void>.value());
        }
        await _extractChain;
        await _releaseTail;
        _held = true;
        _idle = Completer<void>();
        if (!acquired.isCompleted) {
          acquired.complete();
        }
      } catch (e, st) {
        if (!acquired.isCompleted) {
          acquired.completeError(e, st);
        }
      }
    }).catchError((Object e, StackTrace st) {
      if (!acquired.isCompleted) {
        acquired.completeError(e, st);
      }
    });
    await acquired.future;
  }

  /// Queue decoder teardown and clear the decoder lease when finished.
  static void scheduleRelease(Future<void> Function() release) {
    _releaseTail = _releaseTail.then((_) async {
      try {
        await release();
      } finally {
        await Future<void>.delayed(settle);
        _held = false;
        final idle = _idle;
        _idle = null;
        if (idle != null && !idle.isCompleted) {
          idle.complete();
        }
      }
    }).catchError((Object _, StackTrace __) {
      _held = false;
      final idle = _idle;
      _idle = null;
      if (idle != null && !idle.isCompleted) {
        idle.complete();
      }
    });
  }

  /// Run short MPP work (`extract-video-frame`).
  ///
  /// When [waitForDecoder] is true (covers), waits until no page holds a
  /// decoder lease. AI Detect passes false so samples can run during VOD.
  static Future<T> runExclusive<T>(
    Future<T> Function() action, {
    bool waitForDecoder = true,
  }) {
    final result = Completer<T>();
    _extractChain = _extractChain.then((_) async {
      try {
        if (waitForDecoder) {
          while (_held) {
            await (_idle?.future ?? Future<void>.value());
          }
        }
        final value = await action();
        await Future<void>.delayed(settle);
        if (!result.isCompleted) {
          result.complete(value);
        }
      } catch (e, st) {
        await Future<void>.delayed(settle);
        if (!result.isCompleted) {
          result.completeError(e, st);
        }
      }
    }).catchError((Object e, StackTrace st) {
      if (!result.isCompleted) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  /// Test-only: reset static queue state.
  static void debugReset() {
    _acquireLock = Future<void>.value();
    _extractChain = Future<void>.value();
    _releaseTail = Future<void>.value();
    _held = false;
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) {
      idle.complete();
    }
  }
}
