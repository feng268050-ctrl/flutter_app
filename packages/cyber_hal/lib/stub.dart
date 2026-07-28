/// In-memory HAL backends for host unit tests and emergency stubbing.
///
/// P3.2 QEMU guests use Linux backends with `board_id=sim`. Force stubs only via
/// `HAL_BACKEND=stub`:
///
/// ```dart
/// if (resolveHalBackend() == HalBackendKind.stub) {
///   final backlight = StubBacklight();
///   final volume = StubVolume();
///   final autoSleep = StubAutoSleep();
///   final buttonFeedback = StubButtonFeedback();
///   final sysInfo = StubSysInfo();
/// }
/// ```
library;

export 'package:cyber_hal/src/stub/hal_backend.dart';
export 'package:cyber_hal/src/stub/stub_backlight.dart';
export 'package:cyber_hal/src/stub/stub_ip_camera.dart';
export 'package:cyber_hal/src/stub/stub_sys_info.dart';
export 'package:cyber_hal/src/stub/stub_volume.dart';
export 'package:cyber_hal/src/stub/stub_auto_sleep.dart';
export 'package:cyber_hal/src/stub/stub_button_feedback.dart';
export 'package:cyber_hal/src/stub/stub_orientation.dart';
export 'package:cyber_hal/src/stub/stub_usb_otg.dart';
