import 'dart:async';

import 'package:cyber_hal/src/sys_info/product_info.dart';
import 'package:cyber_hal/src/sys_info/sys_info.dart';

/// Fixed [SysInfo] snapshot for host tests and the P3.2 emulator.
final class StubSysInfo implements SysInfo {
  StubSysInfo({
    this.snapshotData = const SysInfoSnapshot(
      serialNumber: 'SIM-0001',
      chipId: 'SIM-CHIP-1',
      brand: 'SimBrand',
      model: 'SimModel',
      boardModel: 'sim',
      kernelRelease: 'stub',
      osName: 'Cyber OS',
      osReleaseId: 'Cyber OS 1.0.0',
      osVersion: '1.0.0',
      appVersion: '0.0-sim',
      cpuCoreCount: 4,
      memoryTotalBytes: 4 * 1024 * 1024 * 1024,
      memoryAvailableBytes: 2 * 1024 * 1024 * 1024,
      storage: [
        // Approximate GPT system footprint (rootfs A+B + oem + boots…).
        StorageInfo(
          mountPoint: '/',
          totalBytes: (2 * 1024 + 128 + 64 * 2) * 1024 * 1024,
          freeBytes: 0,
        ),
        StorageInfo(
          mountPoint: '/userdata',
          totalBytes: 24 * 1024 * 1024 * 1024,
          freeBytes: 13 * 1024 * 1024 * 1024,
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
    this.productInfo = const ProductInfo(
      brand: 'SimBrand',
      model: 'SimModel',
      sn: 'SIM-0001',
      chipId: 'SIM-CHIP-1',
      keys: {
        'brand': 'SimBrand',
        'model': 'SimModel',
        'sn': 'SIM-0001',
        'camera_ip': '192.168.1.100',
      },
    ),
  });

  final SysInfoSnapshot snapshotData;

  /// When set, overrides [SysInfoSnapshot.uiFps] / [rasterFps] from [snapshotData].
  final FrameTimingSampler? frameTimingSampler;

  /// Injected product identity for AppServices / boot self-check.
  final ProductInfo productInfo;

  SysInfoSnapshot get _effectiveSnapshot {
    final s = frameTimingSampler;
    if (s == null) {
      return snapshotData;
    }
    return SysInfoSnapshot(
      serialNumber: snapshotData.serialNumber,
      chipId: snapshotData.chipId,
      brand: snapshotData.brand,
      model: snapshotData.model,
      boardModel: snapshotData.boardModel,
      kernelRelease: snapshotData.kernelRelease,
      osName: snapshotData.osName,
      osReleaseId: snapshotData.osReleaseId,
      osVersion: snapshotData.osVersion,
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
