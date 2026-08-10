import 'package:cyber_hal/output/load_profile.dart';
import 'package:flutter/foundation.dart';

/// App-wide continuous-paint / animation policy driven by HAL [LoadProfile].
///
/// Loaded at startup; updated when Settings changes the mode (no HMI restart).
final class LoadProfileController extends ChangeNotifier {
  LoadProfileController({required LoadProfile backend}) : _backend = backend;

  final LoadProfile _backend;

  LoadProfileMode _mode = LoadProfileMode.performance;
  bool _ready = false;

  LoadProfileMode get mode => _mode;

  /// True after the first [load] completes.
  bool get ready => _ready;

  /// Cut home decorative WebP loops and non-essential continuous paint.
  bool get reduceDecorativeMotion => _mode == LoadProfileMode.balanced;

  /// Snap Settings / chrome page transitions (keep functional progress UX).
  bool get snapPageTransitions => _mode == LoadProfileMode.balanced;

  /// Honor Flutter reduced-motion for widgets that respect it.
  bool get disableAnimations => _mode == LoadProfileMode.balanced;

  Future<void> load() async {
    try {
      _mode = await _backend.getMode();
    } catch (e) {
      debugPrint('load-profile: getMode failed: $e');
      _mode = LoadProfileMode.performance;
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setMode(LoadProfileMode mode) async {
    try {
      await _backend.setMode(mode);
      _mode = mode;
      _ready = true;
      notifyListeners();
    } catch (e) {
      debugPrint('load-profile: setMode failed: $e');
      rethrow;
    }
  }
}
