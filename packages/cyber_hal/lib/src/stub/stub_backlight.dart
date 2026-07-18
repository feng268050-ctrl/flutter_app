import 'package:cyber_hal/output/backlight.dart';
import 'package:cyber_hal/src/linux/percent.dart';

/// In-memory backlight for host tests and the P3.2 emulator.
final class StubBacklight implements Backlight {
  StubBacklight({int initialPercent = 80})
      : _percent = clampPercent(initialPercent);

  int _percent;

  @override
  Future<int> getBrightnessPercent() async => _percent;

  @override
  Future<void> setBrightnessPercent(int percent) async {
    _percent = clampPercent(percent);
  }

  @override
  Future<void> dispose() async {}
}
