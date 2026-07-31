/// Throttles outbound `video.uploading` WS emits (lws-ui `WsThrottle`).
///
/// Emits when percent jumps by ≥5 or at least 2s elapsed since last emit.
/// Callers MUST force-emit the first (0%) and last (100% / terminal) events.
final class ProcessVideoUploadingWsThrottle {
  int _lastPercent = -1;
  DateTime? _lastEmitAt;

  bool shouldEmit(int percent) {
    final p = percent.clamp(0, 100);
    final now = DateTime.now();
    if (_lastPercent < 0) {
      _lastPercent = p;
      _lastEmitAt = now;
      return true;
    }
    if (p - _lastPercent >= 5) {
      _lastPercent = p;
      _lastEmitAt = now;
      return true;
    }
    final last = _lastEmitAt;
    if (last != null && now.difference(last) >= const Duration(seconds: 2)) {
      _lastPercent = p;
      _lastEmitAt = now;
      return true;
    }
    return false;
  }
}
