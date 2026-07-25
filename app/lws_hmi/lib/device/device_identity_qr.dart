/// Device identity QR payload (lws-ui `DeviceQRCodeUtils` v2 parity).
abstract final class DeviceIdentityQr {
  static const delimiter = '|';
  static const formatVersionV2 = '2';

  /// V2 plaintext: `SN|2|Model|SystemVersion` (`|` in fields → `_`).
  static String contentV2({
    required String sn,
    required String model,
    required String systemVersion,
  }) {
    return '${sanitize(sn)}$delimiter$formatVersionV2$delimiter'
        '${sanitize(model)}$delimiter${sanitize(systemVersion)}';
  }

  static String sanitize(String value) => value.replaceAll(delimiter, '_');
}
