/// Serializes control-board Modbus flash between bundled-home and future OTA.
abstract final class FirmwareUpgradeCoordinator {
  static bool _bundledInProgress = false;
  static bool _otaInProgress = false;

  static bool get isBundledUpgradeInProgress => _bundledInProgress;
  static bool get isOtaUpgradeInProgress => _otaInProgress;
  static bool get isBusy => _bundledInProgress || _otaInProgress;

  static bool canStartFirmwareUpgrade() => !isBusy;

  /// Control-board Modbus flash — blocked while whole-device OTA is active.
  static bool canStartBundledFirmwareUpgrade() => canStartFirmwareUpgrade();

  /// Future OTA path: blocked only while bundled is active.
  static bool canStartOtaFirmwareTransfer() => !_bundledInProgress;

  static void markBundledUpgradeStarted() {
    _bundledInProgress = true;
  }

  static void markBundledUpgradeEnded() {
    _bundledInProgress = false;
  }

  static void setOtaUpgradeInProgress(bool inProgress) {
    _otaInProgress = inProgress;
  }

  /// Test / recovery only.
  static void resetForTest() {
    _bundledInProgress = false;
    _otaInProgress = false;
  }
}
