import 'package:cyber_hal/output.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';

/// OS Settings click backend — HAL [ButtonFeedback] shared filesystem sample.
///
/// Preference + MP3 live under `/var/lib/hal/` (product HMI installs the
/// catalog). This App does not ship click assets.
class HalClickSound implements CyberClickSound {
  HalClickSound(this.feedback);

  final ButtonFeedback feedback;

  static const debounceMs = 150;

  int _lastPlayUptimeMs = 0;

  void warmRead() {
    feedback.warmRead();
  }

  @override
  Future<void> playClick() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayUptimeMs < debounceMs) {
      return;
    }
    _lastPlayUptimeMs = now;
    try {
      if (feedback.assetKey.isEmpty) {
        return;
      }
      await feedback.play();
    } catch (e) {
      debugPrint('click-sfx: play failed: $e');
    }
  }
}
