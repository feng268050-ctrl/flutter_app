import 'package:cyber_hal/sys_info.dart';

/// LWS HMI keys and defaults for `/var/lib/hal/properties.ini` tunables.
///
/// HAL [ProductInfo] only knows identity (`brand` / `model` / `sn` / `chipId`).
/// All other keys are opaque [ProductInfo.get] strings — this product layer
/// names them, types them, and applies defaults.

const kPropCameraIp = 'camera_ip';
const kPropCameraType = 'camera_type';
const kPropFocusScaleRef = 'focus_scale_ref';
const kPropControlCardCommAlarmMode = 'control_card_comm_alarm_mode';

const kDefaultCameraIp = '192.168.1.100';
const kDefaultCameraType = '1';
const kDefaultFocusScaleRef = '0';
const kDefaultControlCardCommAlarmMode = 'slide_window';

String effectiveCameraIp(String? raw) {
  final v = (raw ?? '').trim();
  return v.isEmpty ? kDefaultCameraIp : v;
}

String effectiveCameraIpFromProduct(ProductInfo product) =>
    effectiveCameraIp(product.get(kPropCameraIp));

/// Empty/missing → [kDefaultCameraType]; otherwise trimmed raw (`1`/`2`/other).
String effectiveCameraType(String? cameraType) {
  final v = (cameraType ?? '').trim();
  return v.isEmpty ? kDefaultCameraType : v;
}

String effectiveCameraTypeFromProduct(ProductInfo product) =>
    effectiveCameraType(product.get(kPropCameraType));

/// Typed camera type for UI: only `1` or `2`; else empty (before App default).
String typedCameraType(String? raw) {
  final v = (raw ?? '').trim();
  return (v == '1' || v == '2') ? v : '';
}

String typedCameraTypeFromProduct(ProductInfo product) =>
    typedCameraType(product.get(kPropCameraType));

String effectiveFocusScaleRef(String? raw) {
  final v = (raw ?? '').trim();
  return v.isEmpty ? kDefaultFocusScaleRef : v;
}

String effectiveFocusScaleRefFromProduct(ProductInfo product) =>
    effectiveFocusScaleRef(product.get(kPropFocusScaleRef));

/// Absent/blank → [kDefaultControlCardCommAlarmMode]; invalid stays empty.
String effectiveControlCardCommAlarmMode(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) {
    return kDefaultControlCardCommAlarmMode;
  }
  if (v == 'slide_window' || v == 'immediate') {
    return v;
  }
  return '';
}

String effectiveControlCardCommAlarmModeFromProduct(ProductInfo product) =>
    effectiveControlCardCommAlarmMode(product.get(kPropControlCardCommAlarmMode));
