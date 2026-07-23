import 'package:cyber_hal/output/display/backlight.dart';
import 'package:cyber_hal/src/linux/percent.dart';

/// In-memory backlight for host tests and the P3.2 emulator.
final class StubBacklight implements Backlight {
  StubBacklight({int initialPercent = 80})
      : _percent = clampPercent(initialPercent);

  int _percent;
  int _absolute = 80;
  static const maxDevice = 100;

  int get absoluteForTest => _absolute;

  @override
  Future<int> getBrightnessPercent() async => _percent;

  @override
  Future<void> setBrightnessPercent(int percent) async {
    _percent = clampPercent(percent);
    _absolute = backlightPercentToDevice(_percent, maxDevice);
  }

  @override
  Future<void> setAbsoluteBrightness(int deviceValue) async {
    _absolute = deviceValue < 0 ? 0 : deviceValue;
    // When absolute 0, keep last logical percent for callers that restore later.
    if (_absolute > 0) {
      _percent = backlightDeviceToPercent(_absolute, maxDevice);
    }
  }

  @override
  Future<void> dispose() async {}
}
