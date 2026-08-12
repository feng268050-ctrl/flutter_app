import 'package:cyber_hal/output/display/ui_scale.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:flutter/foundation.dart';

/// Linux UiScale: `display.conf` key `ui_scale`.
final class LinuxUiScale implements UiScale {
  LinuxUiScale({this.preferencePath = OutputPrefs.displayConf});

  final String preferencePath;

  double _scale = 1.0;
  bool _warmed = false;

  static const double minScale = 0.5;
  static const double maxScale = 2.0;

  @override
  double get scale => _scale;

  static double clampScale(double value) {
    if (value.isNaN || value.isInfinite) return 1.0;
    return value.clamp(minScale, maxScale);
  }

  @override
  double warmRead() {
    if (_warmed) return _scale;
    try {
      final map = readKeyValueConfFileSync(preferencePath);
      _scale = clampScale(double.tryParse(
              (map[OutputPrefs.keyUiScale] ?? '1.0').trim()) ??
          1.0);
    } catch (e) {
      debugPrint('ui_scale: warmRead failed: $e');
      _scale = 1.0;
    }
    _warmed = true;
    return _scale;
  }

  @override
  Future<double> getScale() async {
    if (_warmed) return _scale;
    try {
      final map = await readKeyValueConfFile(preferencePath);
      _scale = clampScale(double.tryParse(
              (map[OutputPrefs.keyUiScale] ?? '1.0').trim()) ??
          1.0);
    } catch (e) {
      debugPrint('ui_scale: getScale failed: $e');
      _scale = 1.0;
    }
    _warmed = true;
    return _scale;
  }

  @override
  Future<void> setScale(double scale, {bool apply = true}) async {
    final clamped = clampScale(scale);
    await upsertKeyValueConfFile(
      preferencePath,
      {OutputPrefs.keyUiScale: clamped.toStringAsFixed(3)},
    );
    _scale = clamped;
    _warmed = true;
  }

  @override
  Future<void> dispose() async {}
}
