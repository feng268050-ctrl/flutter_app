import 'package:cyber_hal/output/volume.dart';
import 'package:cyber_hal/src/linux/percent.dart';

/// In-memory volume for host tests and the P3.2 emulator.
final class StubVolume implements Volume {
  StubVolume({int initialPercent = 50, bool muted = false})
      : _percent = clampPercent(initialPercent),
        _muted = muted;

  int _percent;
  bool _muted;

  @override
  Future<int> getVolumePercent() async => _percent;

  @override
  Future<void> setVolumePercent(int percent) async {
    _percent = clampPercent(percent);
  }

  @override
  Future<bool> isMuted() async => _muted;

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
  }
}
