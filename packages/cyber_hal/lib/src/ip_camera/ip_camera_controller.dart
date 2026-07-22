import 'package:cyber_hal/src/ip_camera/ip_camera_models.dart';
import 'package:cyber_hal/src/ip_camera/ip_camera_recording.dart';

/// Portable IP network camera: host identity, upstream streams, health,
/// and RTSP-to-file recording.
///
/// Does **not** configure host L3 path (eth0 / Wi‑Fi / internet) or MediaMTX.
/// Construct one instance per camera host; multiple instances may coexist.
abstract class IpCameraController {
  /// Injected at construction (IP or hostname).
  String get cameraHost;

  /// Native streams on [cameraHost] (not local relay fan-out).
  IpCameraStreams get streams;

  Stream<IpCameraHealth> get health;

  /// Last known health (broadcast [health] does not replay).
  IpCameraHealth get currentHealth;

  /// One active recording session for this camera instance.
  IpCameraRecordingController get recording;

  /// Start HAL-owned periodic probes. Idempotent. Does not bring up L3.
  Future<void> startMonitoring();

  /// One-shot probe; coalesces with an in-flight probe. Updates [health].
  Future<IpCameraHealth> probeOnce();

  /// Pause probes while the product reconfigures path to the camera.
  void suspendProbes();

  /// Resume after path work. Optional [configurePingOk] seeds recovery policy
  /// without naming a particular interface.
  void resumeProbes({bool? configurePingOk});

  Future<void> dispose();
}
