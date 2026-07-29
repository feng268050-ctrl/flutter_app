/// Detects consecutive taps within a short window (lws-ui `SecretTapTracker`).
final class SecretTapTracker {
  SecretTapTracker({
    this.requiredTaps = 5,
    this.tapWindow = const Duration(seconds: 5),
  });

  final int requiredTaps;
  final Duration tapWindow;

  int _tapCount = 0;
  DateTime? _resetAfter;

  /// Returns `true` when [requiredTaps] were reached within [tapWindow].
  bool registerTap([DateTime? now]) {
    final t = now ?? DateTime.now();
    final deadline = _resetAfter;
    if (deadline == null || t.isAfter(deadline)) {
      _tapCount = 0;
    }
    _tapCount++;
    _resetAfter = t.add(tapWindow);
    if (_tapCount >= requiredTaps) {
      _tapCount = 0;
      return true;
    }
    return false;
  }

  void reset() {
    _tapCount = 0;
    _resetAfter = null;
  }
}
