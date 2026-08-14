/// On-device paths for [cyber_capture].
abstract final class CapturePaths {
  /// Staging root (survives until host cleanup).
  static const captureRoot = '/var/lib/hmi/capture';

  /// Host writes one command per line (`screenshot`, `record-start`, …).
  static const commandFile = '/run/hmi/capture.cmd';

  /// Native status mirror (`idle` / `armed` / `recording` / `done` / `error:…`).
  static const statusFile = '/var/lib/hmi/capture/status';
}
