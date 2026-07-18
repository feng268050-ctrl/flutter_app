import 'dart:async';

import 'package:cyber_hal/src/sys_info/sys_info.dart';

/// Fixed [SysInfo] snapshot for host tests and the P3.2 emulator.
final class StubSysInfo implements SysInfo {
  StubSysInfo({
    this.snapshotData = const SysInfoSnapshot(
      serialNumber: 'SIM-0001',
      boardModel: 'sim',
      kernelRelease: 'stub',
      osReleaseId: 'sim',
      appVersion: '0.0-sim',
      cpuCoreCount: 4,
      memoryTotalBytes: 4 * 1024 * 1024 * 1024,
      memoryAvailableBytes: 2 * 1024 * 1024 * 1024,
      storage: [
        StorageInfo(
          mountPoint: '/',
          totalBytes: 32 * 1024 * 1024 * 1024,
          freeBytes: 16 * 1024 * 1024 * 1024,
        ),
      ],
      thermal: [
        ThermalZone(
          id: 'thermal_zone0',
          type: 'soc-thermal',
          temperatureCelsius: 40.0,
        ),
        ThermalZone(
          id: 'thermal_zone1',
          type: 'gpu-thermal',
          temperatureCelsius: 38.0,
        ),
      ],
      uptime: Duration(hours: 1),
      loadAverage: LoadAverage(one: 0.1, five: 0.1, fifteen: 0.1),
    ),
  });

  final SysInfoSnapshot snapshotData;

  @override
  Future<SysInfoSnapshot> snapshot() async => snapshotData;

  @override
  Stream<SysInfoUpdate> watch({
    Duration interval = const Duration(seconds: 1),
  }) async* {
    yield SysInfoUpdate(
      kind: SysInfoChangeKind.primed,
      snapshot: snapshotData,
    );
  }

  @override
  Future<void> close() async {}
}
