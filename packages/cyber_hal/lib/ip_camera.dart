/// IP network camera domain (network-dependent input scenario).
///
/// Construct [LinuxIpCameraController] (or a test double) with an explicit
/// [cameraHost]. Path to that host (eth0 / Wi‑Fi / internet) and MediaMTX
/// orchestration are **out of scope** — product Apps compose those separately.
/// Multiple instances with different hosts may coexist. Recording is owned by
/// [IpCameraController.recording] and waits for RTSP media readiness before
/// reporting `recording`.
library;

export 'package:cyber_hal/src/ip_camera/ip_camera_controller.dart';
export 'package:cyber_hal/src/ip_camera/ip_camera_models.dart';
export 'package:cyber_hal/src/ip_camera/ip_camera_probes.dart';
export 'package:cyber_hal/src/ip_camera/ip_camera_recording.dart';
export 'package:cyber_hal/src/ip_camera/linux_ip_camera_controller.dart';
export 'package:cyber_hal/src/ip_camera/linux_ip_camera_recorder.dart';
