import 'package:cyber_hal/output/load_profile.dart';

/// In-memory [LoadProfile] for host tests / stub backend.
final class StubLoadProfile implements LoadProfile {
  StubLoadProfile({
    LoadProfileMode initial = LoadProfileMode.performance,
  }) : _mode = initial;

  LoadProfileMode _mode;

  @override
  Future<LoadProfileMode> getMode() async => _mode;

  @override
  Future<void> setMode(LoadProfileMode mode) async {
    _mode = mode;
  }

  @override
  Future<void> dispose() async {}
}
