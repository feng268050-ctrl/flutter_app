import 'dart:io';

import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LinuxSysInfo.snapshot returns kernel or null without throwing', () async {
    final info = LinuxSysInfo(
      deviceSnReader: const DeviceSnReader(readSerialPath: '/bin/false'),
      appVersion: '0.0-test',
      productIniPath: '/tmp/lws-hmi-missing-product.ini',
      productInfo: ProductInfo.empty,
    );
    final snap = await info.snapshot();
    expect(snap.appVersion, '0.0-test');
    expect(snap.serialNumber, isNull);
    expect(snap.brand, isNull);
    expect(snap.model, isNull);
    // Host may or may not expose /proc; just ensure call completes.
    expect(snap.kernelRelease, anyOf(isNull, isNotEmpty));
    await info.close();
  });

  test('sectorsFileToBytes parses sysfs size', () {
    expect(sectorsFileToBytes('2048\n'), 2048 * 512);
    expect(sectorsFileToBytes('0'), isNull);
    expect(sectorsFileToBytes('x'), isNull);
  });

  test('LinuxSysInfo storage sums system part labels into /', () async {
    final sizes = <String, int>{
      'rootfs_a': 1000,
      'rootfs_b': 1000,
      'oem': 128,
      'boot': 64,
    };
    final info = LinuxSysInfo(
      deviceSnReader: const DeviceSnReader(readSerialPath: '/bin/false'),
      productInfo: ProductInfo.empty,
      mountPoints: const ['/', '/userdata'],
      systemPartLabels: sizes.keys.toList(),
      partSizeReader: (label) async => sizes[label],
    );
    final snap = await info.snapshot();
    final system = snap.storage.where((s) => s.mountPoint == '/').single;
    expect(system.totalBytes, 1000 + 1000 + 128 + 64);
    expect(system.freeBytes, 0);
    await info.close();
  });

  test('parseDfStorageLine handles BusyBox df -Pk', () {
    const out = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/root         1048576    524288    524288      50% /
''';
    final info = parseDfStorageLine(
      stdout: out,
      mountPoint: '/',
      blockSizeBytes: 1024,
    );
    expect(info, isNotNull);
    expect(info!.totalBytes, 1048576 * 1024);
    expect(info.freeBytes, 524288 * 1024);
  });

  test('parseDfStorageLine handles GNU df -B1', () {
    const out = '''
Filesystem     1B-blocks      Used Available Use% Mounted on
/dev/mmcblk0p6 1000000000 600000000 400000000  60% /userdata
''';
    final info = parseDfStorageLine(
      stdout: out,
      mountPoint: '/userdata',
      blockSizeBytes: 1,
    );
    expect(info, isNotNull);
    expect(info!.totalBytes, 1000000000);
    expect(info.freeBytes, 400000000);
  });

  test('StubSysInfo.watch emits primed once', () async {
    final updates = await StubSysInfo().watch().toList();
    expect(updates, hasLength(1));
    expect(updates.first.kind, SysInfoChangeKind.primed);
    expect(updates.first.snapshot.socThermal?.type, 'soc-thermal');
    expect(updates.first.snapshot.gpuThermal?.type, 'gpu-thermal');
    expect(updates.first.snapshot.uiFps, 56.0);
    expect(updates.first.snapshot.rasterFps, 56.0);
    expect(updates.first.snapshot.panelRefreshHz, 56.0);
    expect(updates.first.snapshot.brand, 'SimBrand');
    expect(updates.first.snapshot.model, 'SimModel');
  });

  test('parse Rockchip DRM Display mode refresh', () {
    const sample = '''
Video Port1: ACTIVE
    Connector:DSI-1
    Display mode: 800x1280p56
	dclk[68000 kHz]
''';
    final m = RegExp(r'Display mode:\s*\S+p(\d+(?:\.\d+)?)').firstMatch(sample);
    expect(m, isNotNull);
    expect(double.tryParse(m!.group(1)!), 56.0);
  });

  test('SysInfoSnapshot.socThermal / gpuThermal match types', () {
    const snap = SysInfoSnapshot(
      thermal: [
        ThermalZone(id: 'z0', type: 'soc-thermal', temperatureCelsius: 41),
        ThermalZone(id: 'z1', type: 'gpu-thermal', temperatureCelsius: 39),
      ],
    );
    expect(snap.socThermal?.temperatureCelsius, 41);
    expect(snap.gpuThermal?.temperatureCelsius, 39);
  });

  test('FrameTimingSampler merges into LinuxSysInfo snapshot', () async {
    final info = LinuxSysInfo(
      deviceSnReader: const DeviceSnReader(readSerialPath: '/bin/false'),
      productInfo: ProductInfo.empty,
      frameTimingSampler: const FixedFrameTimingSampler(
        uiFps: 48.5,
        rasterFps: 47.0,
      ),
    );
    final snap = await info.snapshot();
    expect(snap.uiFps, 48.5);
    expect(snap.rasterFps, 47.0);
    expect(snap.volatileSignature, contains('48.5'));
    expect(snap.volatileSignature, contains('47.0'));
    await info.close();
  });

  test('StubSysInfo frameTimingSampler overrides snapshot FPS', () async {
    final info = StubSysInfo(
      frameTimingSampler: const FixedFrameTimingSampler(
        uiFps: 30.0,
        rasterFps: 29.0,
      ),
    );
    final snap = await info.snapshot();
    expect(snap.uiFps, 30.0);
    expect(snap.rasterFps, 29.0);
    expect(snap.socThermal?.temperatureCelsius, 40.0);
  });

  group('ProductIniReader / ProductInfo', () {
    test('parse ignores comments and blanks', () {
      final map = ProductIniReader.parse('''
# comment
brand=Innohi

model=YNH960
''');
      expect(map['brand'], 'Innohi');
      expect(map['model'], 'YNH960');
    });

    test('parse strips matching single and double quotes', () {
      final map = ProductIniReader.parse('''
brand="LaserCyber"
model='L1 Pro'
camera_ip="192.168.1.100"
''');
      expect(map['brand'], 'LaserCyber');
      expect(map['model'], 'L1 Pro');
      expect(map['camera_ip'], '192.168.1.100');
    });

    test('parse keeps unmatched quotes as-is', () {
      final map = ProductIniReader.parse('''
brand="LaserCyber
model=L1 Pro"
''');
      expect(map['brand'], '"LaserCyber');
      expect(map['model'], 'L1 Pro"');
    });

    test('missing file yields empty map', () async {
      final map = await const ProductIniReader(
        path: '/tmp/lws-hmi-definitely-missing-product.ini',
      ).read();
      expect(map, isEmpty);
    });

    test('factory sn preferred over chip serial; chipId stays chip', () async {
      final dir = await Directory.systemTemp.createTemp('product-ini-');
      final script = File('${dir.path}/fake-serial.sh');
      await script.writeAsString('''#!/bin/sh
if [ "\${1:-}" = "--chip-id" ]; then
  echo CHIP-ABC
  exit 0
fi
echo SHOULD-NOT-USE
''');
      await Process.run('chmod', <String>['+x', script.path]);
      final info = await ProductInfo.load(
        keysOverride: {
          'brand': 'FROM-INI',
          'model': 'FROM-INI',
          'sn': 'FROM-INI',
          'camera_ip': '192.168.1.50',
          'camera_type': '2',
        },
        identityOverride: {
          'brand': 'Innohi',
          'model': 'YNH960',
          'sn': 'FACTORY-001',
        },
        deviceSnReader: DeviceSnReader(readSerialPath: script.path),
      );
      expect(info.brand, 'Innohi');
      expect(info.model, 'YNH960');
      expect(info.sn, 'FACTORY-001');
      expect(info.chipId, 'CHIP-ABC');
      expect(info.get('camera_ip'), '192.168.1.50');
      expect(info.get('camera_type'), '2');
      await dir.delete(recursive: true);
    });

    test('chip serial when Vendor Storage sn absent', () async {
      final dir = await Directory.systemTemp.createTemp('product-ini-');
      final script = File('${dir.path}/fake-serial.sh');
      await script.writeAsString('''#!/bin/sh
echo CHIP-ABC
''');
      await Process.run('chmod', <String>['+x', script.path]);
      final info = await ProductInfo.load(
        keysOverride: {'brand': 'FROM-INI'},
        identityOverride: const {},
        deviceSnReader: DeviceSnReader(readSerialPath: script.path),
      );
      expect(info.sn, 'CHIP-ABC');
      expect(info.chipId, 'CHIP-ABC');
      expect(info.brand, isEmpty);
      await dir.delete(recursive: true);
    });

    test('product.ini brand/model/sn ignored for identity', () async {
      final dir = await Directory.systemTemp.createTemp('product-ini-');
      final script = File('${dir.path}/fake-serial.sh');
      await script.writeAsString('''#!/bin/sh
if [ "\${1:-}" = "--chip-id" ]; then
  echo CHIP-ABC
  exit 0
fi
echo CHIP-ABC
''');
      await Process.run('chmod', <String>['+x', script.path]);
      final info = await ProductInfo.load(
        keysOverride: {
          'brand': 'FROM-INI',
          'model': 'FROM-INI',
          'sn': 'FROM-INI',
        },
        identityOverride: const {},
        deviceSnReader: DeviceSnReader(readSerialPath: script.path),
      );
      expect(info.brand, isEmpty);
      expect(info.model, isEmpty);
      expect(info.sn, 'CHIP-ABC');
      expect(info.chipId, 'CHIP-ABC');
      await dir.delete(recursive: true);
    });

    test('opaque get for unknown keys; identity not from ini', () async {
      final info = await ProductInfo.load(
        keysOverride: {
          'camera_type': '9',
          'control_card_comm_alarm_mode': 'bogus',
          'custom_factory_flag': 'yes',
        },
        deviceSnReader: const DeviceSnReader(readSerialPath: '/bin/false'),
      );
      expect(info.get('camera_type'), '9');
      expect(info.get('control_card_comm_alarm_mode'), 'bogus');
      expect(info.get('custom_factory_flag'), 'yes');
      expect(info.get('camera_ip'), isEmpty);
      expect(info.get('missing'), isEmpty);
    });

    test('LinuxSysInfo snapshot includes brand/model/chipId from ProductInfo', () async {
      final info = LinuxSysInfo(
        deviceSnReader: const DeviceSnReader(readSerialPath: '/bin/false'),
        productInfo: const ProductInfo(
          brand: 'Innohi',
          model: 'YNH960',
          sn: 'FACTORY-001',
          chipId: 'CHIP-ABC',
        ),
      );
      final snap = await info.snapshot();
      expect(snap.brand, 'Innohi');
      expect(snap.model, 'YNH960');
      expect(snap.serialNumber, 'FACTORY-001');
      expect(snap.chipId, 'CHIP-ABC');
      await info.close();
    });
  });
}
