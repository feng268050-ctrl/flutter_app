import 'package:cyber_hal/output/display/orientation.dart';

/// In-memory Orientation for host tests / sim.
final class StubOrientation implements Orientation {
  StubOrientation({
    OrientationMode initial = OrientationMode.landscape,
  }) : _mode = initial;

  OrientationMode _mode;

  @override
  Future<OrientationMode> getPreferred() async => _mode;

  @override
  Future<void> setPreferred(
    OrientationMode mode, {
    bool apply = true,
  }) async {
    _mode = mode;
  }

  @override
  Future<void> dispose() async {}
}
