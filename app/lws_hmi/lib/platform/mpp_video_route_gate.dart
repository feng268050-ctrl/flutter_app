import 'dart:async';

/// Serializes Rockchip MPP consumers across Navigator routes.
///
/// eLinux [VideoPlayer] (file VOD + RTSP) shares one MPP context. Opening a
/// second pipeline while the previous route still holds one SIGSEGVs the HMI
/// (exit 139). Pages must [scheduleRelease] on leave / cover, and
/// [beforeAcquire] before creating a new decoder.
abstract final class MppVideoRouteGate {
  static Future<void> _tail = Future<void>.value();

  /// Wait until all previously scheduled releases finish.
  static Future<void> beforeAcquire() => _tail;

  /// Queue a release so the next [beforeAcquire] sees a free decoder.
  static void scheduleRelease(Future<void> Function() release) {
    _tail = _tail.then((_) => release()).catchError((Object _, StackTrace __) {});
  }
}
