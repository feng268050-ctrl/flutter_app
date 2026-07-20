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
      uiFps: 56.0,
      rasterFps: 56.0,
      panelRefreshHz: 56.0,
    ),
    this.frameTimingSampler,
  });

  final SysInfoSnapshot snapshotData;

  /// When set, overrides [SysInfoSnapshot.uiFps] / [rasterFps] from [snapshotData].
  final FrameTimingSampler? frameTimingSampler;

  SysInfoSnapshot get _effectiveSnapshot {
    final s = frameTimingSampler;
    if (s == null) {
      return snapshotData;
    }
    return SysInfoSnapshot(
      serialNumber: snapshotData.serialNumber,
      boardModel: snapshotData.boardModel,
      kernelRelease: snapshotData.kernelRelease,
      osReleaseId: snapshotData.osReleaseId,
      appVersion: snapshotData.appVersion,
      cpuCoreCount: snapshotData.cpuCoreCount,
      cpuFreqMhz: snapshotData.cpuFreqMhz,
      memoryTotalBytes: snapshotData.memoryTotalBytes,
      memoryAvailableBytes: snapshotData.memoryAvailableBytes,
      storage: snapshotData.storage,
      thermal: snapshotData.thermal,
      uptime: snapshotData.uptime,
      loadAverage: snapshotData.loadAverage,
      uiFps: s.uiFps,
      rasterFps: s.rasterFps,
      panelRefreshHz: snapshotData.panelRefreshHz,
    );
  }

  @override
  Future<SysInfoSnapshot> snapshot() async => _effectiveSnapshot;

  @override
  Stream<SysInfoUpdate> watch({
    Duration interval = const Duration(seconds: 1),
  }) async* {
    yield SysInfoUpdate(
      kind: SysInfoChangeKind.primed,
      snapshot: _effectiveSnapshot,
    );
  }

  @override
  Future<void> close() async {}
}
