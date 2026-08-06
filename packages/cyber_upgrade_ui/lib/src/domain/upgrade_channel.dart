/// Product update channel identity.
enum UpgradeChannel {
  /// Whole-device system OTA (`cyber_ota` apply).
  systemOta,

  /// Control-board firmware (typically Modbus).
  controlBoard,

  /// Camera program / firmware (App-owned flash; UI contract only here).
  cameraProgram,
}
