/// Pure filename gate for APK/App-bundled control-board firmware (lws-ui parity).
abstract final class BundledFirmwareVersionGate {
  /// `LSW01H####S####.bin` (case-insensitive).
  static final RegExp filePattern = RegExp(
    r'^LSW01H\d{4}S\d{4}\.bin$',
    caseSensitive: false,
  );

  static bool isValidFirmwareFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return false;
    }
    return filePattern.hasMatch(fileName);
  }

  /// Hardware version from filename (`H` + four digits).
  static int? hardwareVersion(String fileName) {
    if (!isValidFirmwareFileName(fileName)) {
      return null;
    }
    return int.tryParse(fileName.substring(6, 10));
  }

  /// Software version from filename (`S` + four digits).
  static int? softwareVersion(String fileName) {
    if (!isValidFirmwareFileName(fileName)) {
      return null;
    }
    return int.tryParse(fileName.substring(11, 15));
  }

  /// True when HW matches and bundled SW is strictly greater than device SW.
  static bool isUpgradeCandidate({
    required String bundledFileName,
    required int? deviceHw,
    required int? deviceSw,
  }) {
    if (!isValidFirmwareFileName(bundledFileName)) {
      return false;
    }
    final bundledHw = hardwareVersion(bundledFileName);
    final bundledSw = softwareVersion(bundledFileName);
    if (bundledHw == null ||
        bundledSw == null ||
        deviceHw == null ||
        deviceSw == null) {
      return false;
    }
    if (bundledHw != deviceHw) {
      return false;
    }
    return bundledSw > deviceSw;
  }
}
