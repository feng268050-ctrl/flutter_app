import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';

/// Packs a remote snapshot for `device.online` / `command.stat_response`.
final class DeviceRemoteSnapshotPacker {
  DeviceRemoteSnapshotPacker({
    required this.lockStore,
  });

  final DeviceRemoteLockStore lockStore;

  Map<String, Object?> pack({
    required String deviceSn,
    required String brand,
    required String model,
    String? wifiSsid,
    Map<String, Object?>? commonSettings,
    Map<String, Object?>? deviceStatus,
    Map<String, Object?>? deviceData,
    Map<String, Object?>? processParameters,
    List<Object?>? warns,
  }) {
    return {
      'staticData': {
        'systemVersion': kSystemVersion,
        'systemVersionCode': kSystemVersionCode,
      },
      'deviceInfo': {
        'sn': deviceSn,
        'brand': brand,
        'model': model,
      },
      'commonSettings': commonSettings ?? const <String, Object?>{},
      'deviceStatus': deviceStatus ?? const <String, Object?>{},
      'deviceData': deviceData ?? const <String, Object?>{},
      'processParameters': processParameters,
      'warns': warns ?? const <Object?>[],
      'isLocked': lockStore.isLocked,
      'wifiInfo': {
        if (wifiSsid != null) 'ssid': wifiSsid,
      },
    };
  }
}
