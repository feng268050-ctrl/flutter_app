import 'package:lws_hmi/device/product_property_defaults.dart';

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

/// NameOverlay text: same string as Device Information → Device Model.
///
/// When both brand and model are missing, returns empty (do not burn `-` onto OSD).
String cameraOverlayDeviceName(String? brand, String? model) {
  final display = productDeviceModelDisplay(brand, model);
  return display == kUnavailableDisplay ? '' : display;
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

/// Camera Type row: `1` → Blue Light, `2` → Red Light; empty → default `1`; else `-`.
///
/// Prefer [productCameraTypeDisplayLocalized] when [AppLocalizations] is available.
String productCameraTypeDisplay(String? cameraType) {
  switch (effectiveCameraType(cameraType)) {
    case '1':
      return 'Blue Light';
    case '2':
      return 'Red Light';
    default:
      return kUnavailableDisplay;
  }
}

/// Localized Camera Type labels (Blue Light / Red Light).
String productCameraTypeDisplayLocalized(
  String? cameraType, {
  required String blueLight,
  required String redLight,
}) {
  switch (effectiveCameraType(cameraType)) {
    case '1':
      return blueLight;
    case '2':
      return redLight;
    default:
      return kUnavailableDisplay;
  }
}
