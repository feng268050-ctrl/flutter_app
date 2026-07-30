import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/device_remote_lock_store.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

void main() {
  group('DeviceRemoteSnapshotPacker', () {
    late DeviceRemoteLockStore lock;
    late DeviceRemoteSnapshotPacker packer;

    setUp(() {
      lock = DeviceRemoteLockStore(
        preferencePath: '/tmp/lws-hmi-test-remote-lock.json',
      );
      packer = DeviceRemoteSnapshotPacker(lockStore: lock);
    });

    test('pack is canonical for cloud ingest', () {
      final snap = packer.pack(
        deviceSn: 'baaaf748631f2489',
        brand: 'LaserCyber',
        model: 'L1 Pro',
        cameraIp: '192.168.1.100',
        commonSettings: {
          'language': 'zh-CN',
          'unit': 'Metric',
          'soundEffect': 0,
          'showBootSelfCheck': true,
          'showSafetyGroundLockAlarm': true,
        },
        wifi: const WifiConnectionState(
          phase: WifiConnectionPhase.connected,
          ssid: 'Lab',
          ipv4: '10.0.2.22',
          signalDbm: -50,
        ),
      );
      expect(isCanonicalDeviceStatData(snap), isTrue);
      expect(snap['wifiInfo'], isA<Map>());
      expect((snap['wifiInfo'] as Map)['ssid'], 'Lab');
      expect((snap['wifiInfo'] as Map)['ipAddress'], '10.0.2.22');
      expect((snap['deviceInfo'] as Map)['deviceSn'], 'baaaf748631f2489');
      expect((snap['staticData'] as Map)['commonUseText'], 'unknown');
    });

    test('wifiInfo is null when disconnected', () {
      final snap = packer.pack(
        deviceSn: 'x',
        brand: 'b',
        model: 'm',
        wifi: WifiConnectionState.disconnected,
      );
      expect(snap['wifiInfo'], isNull);
      expect(isCanonicalDeviceStatData(snap), isTrue);
    });
  });
}
