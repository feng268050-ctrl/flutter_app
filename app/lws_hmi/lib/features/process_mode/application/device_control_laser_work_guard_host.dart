import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';

/// Bridges [DeviceControlController] into [LaserWorkGuard] (Quick/Engineer).
///
/// Uses [DeviceControlController.forceDisableLaserForSafety] so local Laser
/// Enable UI clears even when Modbus writes fail (lws-ui
/// `forceLaserOffForGuardedAlarm` → `switchLaserEnable(false)`).
final class DeviceControlLaserWorkGuardHost implements LaserWorkGuardHost {
  DeviceControlLaserWorkGuardHost(this._device);

  final DeviceControlController _device;

  @override
  bool get isLaserEnableActive => _device.laserEnable;

  @override
  Future<void> forceLaserOffForGuardedAlarm() =>
      _device.forceDisableLaserForSafety();
}
