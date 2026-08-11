/// Operator UI scale preference (shared across HMI + OS Settings seats).
library;

/// Portable UI scale API — persisted in `/var/lib/hal/display.conf` as
/// `ui_scale` (default 1.0 = physical 1:1 / no rematch; non-integer OK).
abstract class UiScale {
  double get scale;

  /// Synchronous warm-read for App bootstrap.
  double warmRead();

  Future<double> getScale();

  Future<void> setScale(double scale, {bool apply = true});

  Future<void> dispose();
}
