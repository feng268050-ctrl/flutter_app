import 'package:cyber_hal/stub.dart';
import 'package:cyber_hal/sys_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LinuxSysInfo.snapshot returns kernel or null without throwing', () async {
    final info = LinuxSysInfo(
      deviceSnReader: const DeviceSnReader(readSerialPath: '/bin/false'),
      appVersion: '0.0-test',
    );
    final snap = await info.snapshot();
    expect(snap.appVersion, '0.0-test');
    expect(snap.serialNumber, isNull);
    // Host may or may not expose /proc; just ensure call completes.
    expect(snap.kernelRelease, anyOf(isNull, isNotEmpty));
    await info.close();
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
}
