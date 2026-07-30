import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Packs a remote snapshot for `device.online` / `command.stat_response`.
///
/// Shape aligns with lws-ui `DeviceRemoteSnapshot` + api-server
/// `isCanonicalDeviceStatData` (staticData / deviceInfo / commonSettings /
/// deviceStatus / deviceData / warns).
final class DeviceRemoteSnapshotPacker {
  DeviceRemoteSnapshotPacker({
    required this.lockStore,
  });

  final DeviceRemoteLockStore lockStore;

  Map<String, Object?> pack({
    required String deviceSn,
    required String brand,
    required String model,
    String systemVersion = kSystemVersion,
    int systemVersionCode = kSystemVersionCode,
    String cameraIp = '',
    String cameraVersion = '-',
    String hostIp = '',
    int focusScaleRef = 0,
    String commonUseText = 'unknown',
    Map<String, Object?>? deviceInfo,
    Map<String, Object?>? commonSettings,
    Map<String, Object?>? deviceStatus,
    Map<String, Object?>? deviceData,
    Map<String, Object?>? processParameters,
    List<Object?>? warns,
    WifiConnectionState? wifi,
  }) {
    final sn = deviceSn.trim();
    return {
      'staticData': {
        'systemVersion': systemVersion,
        'systemVersionCode': systemVersionCode,
        'commonUseText': commonUseText,
      },
      'deviceInfo': deviceInfo ??
          {
            'sn': sn,
            'deviceSn': sn,
            'brand': brand,
            'model': model,
            'systemVersion': systemVersion,
            'cameraIp': cameraIp,
            'cameraVersion': cameraVersion,
            'hostIp': hostIp,
            'focusScaleRef': focusScaleRef,
          },
      'commonSettings': commonSettings ?? const <String, Object?>{},
      'deviceStatus': deviceStatus ?? const <String, Object?>{},
      'deviceData': deviceData ?? const <String, Object?>{},
      'processParameters': processParameters,
      'warns': warns ?? const <Object?>[],
      'isLocked': lockStore.isLocked,
      'wifiInfo': wifiInfoFromConnection(wifi),
    };
  }

  /// lws-ui: JSON `null` when not on Wi‑Fi with a usable LAN address.
  static Map<String, Object?>? wifiInfoFromConnection(WifiConnectionState? wifi) {
    if (wifi == null) {
      return null;
    }
    if (wifi.phase != WifiConnectionPhase.connected) {
      return null;
    }
    final ssid = (wifi.ssid ?? '').trim();
    final ip = (wifi.ipv4 ?? '').trim();
    if (ssid.isEmpty || ip.isEmpty || ip == '0.0.0.0') {
      return null;
    }
    return {
      'ssid': ssid,
      if ((wifi.bssid ?? '').isNotEmpty) 'bssid': wifi.bssid,
      'ipAddress': ip,
      if (wifi.prefixLength != null)
        'subnetMask': _subnetMaskFromPrefix(wifi.prefixLength!),
      if ((wifi.gateway ?? '').isNotEmpty) 'router': wifi.gateway,
      if ((wifi.dns ?? '').isNotEmpty) 'dns': wifi.dns,
      if (wifi.signalDbm != null) 'rssi': wifi.signalDbm,
      if (wifi.linkSpeedMbps != null) 'linkSpeed': wifi.linkSpeedMbps,
      if (wifi.frequencyMhz != null) 'frequency': wifi.frequencyMhz,
      if ((wifi.security ?? '').isNotEmpty) 'securityType': wifi.security,
      if ((wifi.macAddress ?? '').isNotEmpty) 'macAddress': wifi.macAddress,
    };
  }

  static String _subnetMaskFromPrefix(int prefix) {
    final p = prefix.clamp(0, 32);
    var mask = p == 0 ? 0 : (0xFFFFFFFF << (32 - p)) & 0xFFFFFFFF;
    return '${(mask >> 24) & 0xFF}.'
        '${(mask >> 16) & 0xFF}.'
        '${(mask >> 8) & 0xFF}.'
        '${mask & 0xFF}';
  }
}

/// True when [stat] satisfies api-server `isCanonicalDeviceStatData`.
bool isCanonicalDeviceStatData(Map<String, Object?> stat) {
  bool isObj(Object? v) => v is Map && v is! List;
  final hasCommon = stat.containsKey('commonSettings') && isObj(stat['commonSettings']);
  final hasAdvanced =
      stat.containsKey('advancedSettings') && isObj(stat['advancedSettings']);
  return isObj(stat['staticData']) &&
      isObj(stat['deviceInfo']) &&
      (hasCommon || hasAdvanced) &&
      (stat['deviceStatus'] == null || isObj(stat['deviceStatus'])) &&
      (stat['deviceData'] == null || isObj(stat['deviceData'])) &&
      stat['warns'] is List;
}
