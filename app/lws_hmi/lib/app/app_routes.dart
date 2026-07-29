/// Named routes for product Home, Settings, Monitor, and hidden Demo.
///
/// Boot self-check is a Home overlay (not a route). Each top-level route calls
/// [scheduleEnsureModbusLive] so live Modbus works even if entry is not Home.
abstract final class AppRoutes {
  static const home = '/';
  static const settings = '/settings';
  static const monitor = '/monitor';
  static const quickMode = '/process-library/quick';
  static const engineerMode = '/process-library/engineer';
  static const demo = '/demo';
  static const processVideoDetail = '/monitor/process-video';
}
