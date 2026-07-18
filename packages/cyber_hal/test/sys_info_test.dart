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
}
