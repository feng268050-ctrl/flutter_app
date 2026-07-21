import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/sys_info/product_info.dart';
import 'package:flutter/foundation.dart';

export 'package:cyber_hal/src/sys_info/product_info.dart';

/// Host/board inventory snapshot (D17).
abstract class SysInfo {
  Future<SysInfoSnapshot> snapshot();

  /// Periodic snapshots: first event is [SysInfoChangeKind.primed], then
  /// [SysInfoChangeKind.changed] when volatile fields differ (thermal, CPU
  /// freq, available RAM, load). Identity fields are included every time.
  ///
  /// Default interval is 1s (thermal-friendly; not Modbus-rate).
  Stream<SysInfoUpdate> watch({
    Duration interval = const Duration(seconds: 1),
  });

  Future<void> close();
}

enum SysInfoChangeKind { primed, changed }

final class SysInfoUpdate {
  const SysInfoUpdate({required this.kind, required this.snapshot});

  final SysInfoChangeKind kind;
  final SysInfoSnapshot snapshot;

  bool get isPrimed => kind == SysInfoChangeKind.primed;
}

/// Optional UI/raster FPS source (typically Flutter [TimingsCallback] at ~1 Hz).
///
/// Kept out of the HAL Linux backends so host/stub can supply fixed values and
/// the App can inject a Flutter-binding sampler without coupling cyber_hal to
/// SchedulerBinding.
abstract class FrameTimingSampler {
  double? get uiFps;
  double? get rasterFps;
}

/// Fixed FPS values for stub / tests.
final class FixedFrameTimingSampler implements FrameTimingSampler {
  const FixedFrameTimingSampler({this.uiFps, this.rasterFps});

  @override
  final double? uiFps;

  @override
  final double? rasterFps;
}

final class SysInfoSnapshot {
  const SysInfoSnapshot({
    this.serialNumber,
    this.chipId,
    this.brand,
    this.model,
    this.boardModel,
    this.kernelRelease,
    this.osReleaseId,
    this.appVersion,
    this.cpuCoreCount,
    this.cpuFreqMhz,
    this.memoryTotalBytes,
    this.memoryAvailableBytes,
    this.storage = const [],
    this.thermal = const [],
    this.uptime,
    this.loadAverage,
    this.uiFps,
    this.rasterFps,
    this.panelRefreshHz,
  });

  /// Product SN (`product.ini` `sn` or chip ID); null if empty.
  final String? serialNumber;

  /// Chip / SoC serial (never factory `product.ini` `sn`); null if empty.
  final String? chipId;

  /// Factory brand from `product.ini`; null if empty.
  final String? brand;

  /// Factory product model from `product.ini` (not DT [boardModel]); null if empty.
  final String? model;

  final String? boardModel;
  final String? kernelRelease;
  final String? osReleaseId;
  final String? appVersion;
  final int? cpuCoreCount;
  final double? cpuFreqMhz;
  final int? memoryTotalBytes;
  final int? memoryAvailableBytes;
  final List<StorageInfo> storage;
  final List<ThermalZone> thermal;
  final Duration? uptime;
  final LoadAverage? loadAverage;

  /// Build/UI thread FPS over the sampler window (typically ~1s), or null.
  final double? uiFps;

  /// Raster thread FPS over the sampler window (typically ~1s), or null.
  final double? rasterFps;

  /// Active DRM display mode refresh (Hz), e.g. Rockchip `800x1280p56` → 56.
  final double? panelRefreshHz;

  /// Prefer `soc-thermal` / types containing `soc` (RK356x).
  ThermalZone? get socThermal => _thermalMatching('soc');

  /// Prefer `gpu-thermal` / types containing `gpu`.
  ThermalZone? get gpuThermal => _thermalMatching('gpu');

  ThermalZone? _thermalMatching(String needle) {
    final n = needle.toLowerCase();
    for (final z in thermal) {
      final type = z.type?.toLowerCase() ?? '';
      if (type.contains(n)) {
        return z;
      }
    }
    return null;
  }

  /// Signature for change-only watch (excludes uptime — always moves).
  String get volatileSignature {
    final zones = thermal
        .map(
          (z) =>
              '${z.id}:${z.type ?? ''}:${z.temperatureCelsius?.toStringAsFixed(2) ?? ''}',
        )
        .join('|');
    final load = loadAverage == null
        ? ''
        : '${loadAverage!.one},${loadAverage!.five},${loadAverage!.fifteen}';
    final ui = uiFps?.toStringAsFixed(1) ?? '';
    final rast = rasterFps?.toStringAsFixed(1) ?? '';
    return '$zones|${cpuFreqMhz ?? ''}|${memoryAvailableBytes ?? ''}|$load|$ui|$rast';
  }
}

final class StorageInfo {
  const StorageInfo({
    required this.mountPoint,
    this.totalBytes,
    this.freeBytes,
  });

  final String mountPoint;
  final int? totalBytes;
  final int? freeBytes;
}

final class ThermalZone {
  const ThermalZone({
    required this.id,
    this.type,
    this.temperatureCelsius,
  });

  final String id;
  final String? type;
  final double? temperatureCelsius;
}

final class LoadAverage {
  const LoadAverage({
    required this.one,
    required this.five,
    required this.fifteen,
  });

  final double one;
  final double five;
  final double fifteen;
}

/// Reads board identity used for USB gadget iSerial (`/usr/bin/read-serial`).
class DeviceSnReader {
  const DeviceSnReader({
    this.readSerialPath = '/usr/bin/read-serial',
    this.unavailableDisplay = '-',
  });

  final String readSerialPath;

  /// Placeholder returned on any failure (App may use its own display constant).
  final String unavailableDisplay;

  /// Product SN (product.ini `sn` preferred, else chip ID).
  Future<String> read() => _run(const <String>[]);

  /// Chip / SoC ID only (`read-serial --chip-id`).
  Future<String> readChipId() => _run(const <String>['--chip-id']);

  Future<String> _run(List<String> args) async {
    try {
      final result = await Process.run(readSerialPath, args);
      if (result.exitCode != 0) {
        return unavailableDisplay;
      }
      final out = (result.stdout is String)
          ? result.stdout as String
          : result.stdout.toString();
      final sn = out.trim();
      if (sn.isEmpty) {
        return unavailableDisplay;
      }
      return sn;
    } catch (_) {
      return unavailableDisplay;
    }
  }
}

/// Linux [SysInfo] from procfs/sysfs + `product.ini` / `read-serial`.
class LinuxSysInfo implements SysInfo {
  LinuxSysInfo({
    this.deviceSnReader = const DeviceSnReader(),
    this.appVersion,
    this.mountPoints = const <String>['/', '/userdata'],
    this.frameTimingSampler,
    this.productIniPath = '/var/lib/hmi/product.ini',
    ProductInfo? productInfo,
  }) : _productInfo = productInfo;

  final DeviceSnReader deviceSnReader;

  /// Optional app/package version supplied by the App.
  final String? appVersion;

  final List<String> mountPoints;

  /// Optional FPS sampler (App injects Flutter timings; stub uses fixed).
  final FrameTimingSampler? frameTimingSampler;

  /// Path to factory product identity file.
  final String productIniPath;

  ProductInfo? _productInfo;

  final StreamController<SysInfoUpdate> _updates =
      StreamController<SysInfoUpdate>.broadcast();
  Timer? _timer;
  Duration _interval = const Duration(seconds: 1);
  bool _busy = false;
  bool _primed = false;
  String? _lastVolatile;
  int _listenCount = 0;
  bool _closed = false;
  double? _cachedPanelRefreshHz;
  bool _panelRefreshResolved = false;

  /// Cached [ProductInfo] (loaded once per process / until [close]).
  Future<ProductInfo> ensureProductInfo() async {
    return _productInfo ??= await ProductInfo.load(
      path: productIniPath,
      deviceSnReader: deviceSnReader,
    );
  }

  @override
  Future<SysInfoSnapshot> snapshot() async {
    final product = await ensureProductInfo();
    final sampler = frameTimingSampler;
    return SysInfoSnapshot(
      serialNumber: product.sn.isEmpty ? null : product.sn,
      chipId: product.chipId.isEmpty ? null : product.chipId,
      brand: product.brand.isEmpty ? null : product.brand,
      model: product.model.isEmpty ? null : product.model,
      boardModel: await _readBoardModel(),
      kernelRelease: await _readKernelRelease(),
      osReleaseId: await _readOsReleaseId(),
      appVersion: appVersion,
      cpuCoreCount: await _readCpuCoreCount(),
      cpuFreqMhz: await _readCpuFreqMhz(),
      memoryTotalBytes: await _readMemKb('MemTotal'),
      memoryAvailableBytes: await _readMemKb('MemAvailable'),
      storage: await _readStorage(),
      thermal: await _readThermal(),
      uptime: await _readUptime(),
      loadAverage: await _readLoadAverage(),
      uiFps: sampler?.uiFps,
      rasterFps: sampler?.rasterFps,
      panelRefreshHz: await _readPanelRefreshHz(),
    );
  }

  @override
  Stream<SysInfoUpdate> watch({
    Duration interval = const Duration(seconds: 1),
  }) {
    if (_closed) {
      return const Stream.empty();
    }
    _interval = interval;
    late final StreamController<SysInfoUpdate> gate;
    gate = StreamController<SysInfoUpdate>(
      onListen: () {
        _listenCount++;
        final sub = _updates.stream.listen(
          gate.add,
          onError: gate.addError,
          onDone: gate.close,
        );
        gate.onCancel = () async {
          await sub.cancel();
          _listenCount--;
          if (_listenCount <= 0) {
            _stopPolling();
          }
        };
        unawaited(_ensurePolling());
      },
    );
    return gate.stream;
  }

  @override
  Future<void> close() async {
    _closed = true;
    _stopPolling();
    await _updates.close();
  }

  Future<void> _ensurePolling() async {
    if (_closed || _timer != null) {
      return;
    }
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_pollTick());
    });
    await _pollTick();
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    _primed = false;
    _lastVolatile = null;
  }

  Future<void> _pollTick() async {
    if (_closed || _busy || !_updates.hasListener) {
      return;
    }
    _busy = true;
    try {
      final snap = await snapshot();
      final sig = snap.volatileSignature;
      if (!_primed) {
        _primed = true;
        _lastVolatile = sig;
        _updates.add(
          SysInfoUpdate(kind: SysInfoChangeKind.primed, snapshot: snap),
        );
        return;
      }
      if (sig == _lastVolatile) {
        return;
      }
      _lastVolatile = sig;
      _updates.add(
        SysInfoUpdate(kind: SysInfoChangeKind.changed, snapshot: snap),
      );
    } catch (e, st) {
      if (!_updates.isClosed) {
        _updates.addError(e, st);
      }
    } finally {
      _busy = false;
    }
  }

  Future<String?> _readBoardModel() async {
    for (final path in <String>[
      '/proc/device-tree/model',
      '/sys/firmware/devicetree/base/model',
    ]) {
      try {
        final f = File(path);
        if (!await f.exists()) {
          continue;
        }
        final raw = await f.readAsBytes();
        final s = String.fromCharCodes(raw.where((b) => b != 0)).trim();
        if (s.isNotEmpty) {
          return s;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _readKernelRelease() async {
    try {
      final r = await Process.run('uname', const <String>['-r']);
      if (r.exitCode == 0) {
        final out = (r.stdout as String).trim();
        if (out.isNotEmpty) {
          return out;
        }
      }
    } catch (_) {}
    try {
      final v = (await File('/proc/version').readAsString()).trim();
      final m = RegExp(r'version\s+(\S+)').firstMatch(v);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readOsReleaseId() async {
    try {
      final lines = await File('/etc/os-release').readAsLines();
      for (final line in lines) {
        if (line.startsWith('PRETTY_NAME=')) {
          var v = line.substring('PRETTY_NAME='.length).trim();
          if (v.startsWith('"') && v.endsWith('"')) {
            v = v.substring(1, v.length - 1);
          }
          return v;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<int?> _readCpuCoreCount() async {
    try {
      return Platform.numberOfProcessors;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _readCpuFreqMhz() async {
    try {
      final f = File('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq');
      if (!await f.exists()) {
        return null;
      }
      final khz = int.tryParse((await f.readAsString()).trim());
      if (khz == null) {
        return null;
      }
      return khz / 1000.0;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readMemKb(String key) async {
    try {
      final lines = await File('/proc/meminfo').readAsLines();
      for (final line in lines) {
        if (!line.startsWith(key)) {
          continue;
        }
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 2) {
          return null;
        }
        final kb = int.tryParse(parts[1]);
        return kb == null ? null : kb * 1024;
      }
    } catch (_) {}
    return null;
  }

  Future<List<StorageInfo>> _readStorage() async {
    final out = <StorageInfo>[];
    for (final mp in mountPoints) {
      try {
        final stat = await Process.run('df', <String>['-B1', mp]);
        if (stat.exitCode != 0) {
          continue;
        }
        final lines = (stat.stdout as String).trim().split('\n');
        if (lines.length < 2) {
          continue;
        }
        final cols = lines.last.trim().split(RegExp(r'\s+'));
        if (cols.length < 4) {
          continue;
        }
        out.add(
          StorageInfo(
            mountPoint: mp,
            totalBytes: int.tryParse(cols[1]),
            freeBytes: int.tryParse(cols[3]),
          ),
        );
      } catch (_) {}
    }
    return out;
  }

  Future<List<ThermalZone>> _readThermal() async {
    final out = <ThermalZone>[];
    try {
      final root = Directory('/sys/class/thermal');
      if (!await root.exists()) {
        return out;
      }
      final dirs = await root.list().where((e) => e is Directory).toList();
      dirs.sort((a, b) => a.path.compareTo(b.path));
      for (final entity in dirs) {
        final dir = entity as Directory;
        final base = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!base.startsWith('thermal_zone')) {
          continue;
        }
        String? type;
        double? tempC;
        try {
          final typeFile = File('${dir.path}/type');
          if (await typeFile.exists()) {
            type = (await typeFile.readAsString()).trim();
          }
        } catch (_) {}
        try {
          final tempFile = File('${dir.path}/temp');
          if (await tempFile.exists()) {
            final milli = int.tryParse((await tempFile.readAsString()).trim());
            if (milli != null) {
              tempC = milli / 1000.0;
            }
          }
        } catch (_) {}
        out.add(ThermalZone(id: base, type: type, temperatureCelsius: tempC));
      }
    } catch (e) {
      debugPrint('sys_info: thermal read failed: $e');
    }
    return out;
  }

  Future<Duration?> _readUptime() async {
    try {
      final raw = (await File('/proc/uptime').readAsString()).trim();
      final sec = double.tryParse(raw.split(RegExp(r'\s+')).first);
      if (sec == null) {
        return null;
      }
      return Duration(milliseconds: (sec * 1000).round());
    } catch (_) {
      return null;
    }
  }

  Future<LoadAverage?> _readLoadAverage() async {
    try {
      final raw = (await File('/proc/loadavg').readAsString()).trim();
      final parts = raw.split(RegExp(r'\s+'));
      if (parts.length < 3) {
        return null;
      }
      final one = double.tryParse(parts[0]);
      final five = double.tryParse(parts[1]);
      final fifteen = double.tryParse(parts[2]);
      if (one == null || five == null || fifteen == null) {
        return null;
      }
      return LoadAverage(one: one, five: five, fifteen: fifteen);
    } catch (_) {
      return null;
    }
  }

  /// Panel mode refresh from Rockchip DRM debugfs (`Display mode: 800x1280p56`).
  /// Cached after first successful read (mode rarely changes while HMI runs).
  Future<double?> _readPanelRefreshHz() async {
    if (_panelRefreshResolved) {
      return _cachedPanelRefreshHz;
    }
    _panelRefreshResolved = true;
    try {
      await Process.run('mount', const <String>[
        '-t',
        'debugfs',
        'none',
        '/sys/kernel/debug',
      ]);
    } catch (_) {}
    try {
      final dri = Directory('/sys/kernel/debug/dri');
      if (!await dri.exists()) {
        return null;
      }
      final cards = await dri.list().where((e) => e is Directory).toList();
      cards.sort((a, b) => a.path.compareTo(b.path));
      // Rockchip: `Display mode: 800x1280p56` (integer or fractional Hz).
      final modeRe = RegExp(r'Display mode:\s*\S+p(\d+(?:\.\d+)?)');
      for (final card in cards) {
        final summary = File('${card.path}/summary');
        if (!await summary.exists()) {
          continue;
        }
        final text = await summary.readAsString();
        final m = modeRe.firstMatch(text);
        if (m == null) {
          continue;
        }
        final hz = double.tryParse(m.group(1)!);
        if (hz != null && hz > 0) {
          _cachedPanelRefreshHz = hz;
          return hz;
        }
      }
    } catch (e) {
      debugPrint('sys_info: DRM panel refresh read failed: $e');
    }
    return null;
  }
}
