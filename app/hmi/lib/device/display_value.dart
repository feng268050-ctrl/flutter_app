/// Shared display placeholder when a field cannot be read.
const String kUnavailableDisplay = '-';

/// Device Model row: `brand + " " + model` with each missing part as `-`.
///
/// Empty inputs → `-`. Computed `- -` (both missing) → `-`.
String productDeviceModelDisplay(String? brand, String? model) {
  final b = (brand == null || brand.trim().isEmpty)
      ? kUnavailableDisplay
      : brand.trim();
  final m = (model == null || model.trim().isEmpty)
      ? kUnavailableDisplay
      : model.trim();
  final joined = '$b $m';
  if (joined == '$kUnavailableDisplay $kUnavailableDisplay') {
    return kUnavailableDisplay;
  }
  return joined;
}

/// Model field for QR / identity payloads (no `-` placeholders).
String productDeviceModelForQr(String? brand, String? model) {
  final b = (brand ?? '').trim();
  final m = (model ?? '').trim();
  if (b.isEmpty && m.isEmpty) {
    return '';
  }
  if (b.isEmpty) {
    return m;
  }
  if (m.isEmpty) {
    return b;
  }
  return '$b $m';
}

/// Camera Type row: `1` → Blue Light, `2` → Red Light; else `-`.
String productCameraTypeDisplay(String? cameraType) {
  switch ((cameraType ?? '').trim()) {
    case '1':
      return 'Blue Light';
    case '2':
      return 'Red Light';
    default:
      return kUnavailableDisplay;
  }
}
