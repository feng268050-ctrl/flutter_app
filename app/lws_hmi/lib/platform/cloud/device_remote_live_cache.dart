import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_gate.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_live_cache_seed.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot_modbus_mapper.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_snapshot_store.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_snapshot.dart';
import 'package:lws_hmi/platform/local_http/monitor_stat_sse_hub.dart';

/// App-owned live `deviceStatus`/`deviceData` cache for LAN Monitor SSE / remote
/// snapshot (MemoryCache role — fed by HAL `watchAttributes`, not a second poll).
final class DeviceRemoteLiveCache {
  DeviceRemoteLiveCache({
    required this.services,
    required this.statHub,
    ProcessParametersSnapshotStore? processStore,
  }) : processStore = processStore ?? ProcessParametersSnapshotStore.instance;

  final AppServices services;
  final MonitorStatSseHub statHub;
  final ProcessParametersSnapshotStore processStore;

  final Map<String, Object?> _statusAttrs = {};
  final Map<String, Object?> _dataAttrs = {};
  final Set<String> _statusIds = {};
  final Set<String> _dataIds = {};

  int _cameraStatus = 0;
  bool? _statusTruncated;
  bool? _dataTruncated;

  MonitorStatSnapshot _published = MonitorStatSnapshot.empty;
  bool _started = false;
  bool _remapScheduled = false;

  StreamSubscription<List<ModbusAttributeChange>>? _attrSub;
  StreamSubscription<ModbusHealth>? _healthSub;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;

  MonitorStatSnapshot currentSnapshot() => _buildSnapshot();

  /// Start HAL watches (idempotent). Call after [AppServices.ensureModbusLive].
  ///
  /// Defers Modbus seed/watch until [BootSelfCheckGate] releases the bus —
  /// concurrent group reads during self-check corrupt RTU framing.
  /// Prefers [BootSelfCheckLiveCacheSeed] when self-check already read the
  /// continuous groups. Camera status may still start during self-check.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    processStore.addListener(_onProcessStoreChanged);

    unawaited(_startCameraStatus());
    await _startModbusWatches();
    _publishIfChanged();
  }

  Future<void> _startCameraStatus() async {
    try {
      final session = await services.ensureIpCamera();
      _applyCameraStatus(session.camera.currentHealth.isHealthy ? 1 : 0);
      _cameraSub = session.status.listen((s) {
        final healthy = s.phase == IpCameraUiPhase.connected;
        _applyCameraStatus(healthy ? 1 : 0);
      });
      unawaited(session.start());
    } catch (e) {
      debugPrint('live-cache: camera status failed: $e');
      _applyCameraStatus(0);
    }
  }

  Future<void> _startModbusWatches() async {
    try {
      await BootSelfCheckGate.waitForModbusAccess();
      await services.ensureModbusLive();
      final modbus = services.modbus;
      _statusIds
        ..clear()
        ..addAll(await modbus.attributeIdsForGroups(const ['status']));
      _dataIds
        ..clear()
        ..addAll(await modbus.attributeIdsForGroups(const ['data']));
      final ids = <String>{..._statusIds, ..._dataIds}.toList(growable: false);

      // Prefer boot self-check group maps; only RTU-read groups that were
      // missing so the first SSE publish is still a full attr map.
      final seededStatus = BootSelfCheckLiveCacheSeed.takeStatus();
      final seededData = BootSelfCheckLiveCacheSeed.takeData();
      if (seededStatus != null) {
        _statusAttrs
          ..clear()
          ..addAll(seededStatus);
        debugPrint(
          'live-cache: seeded status from boot self-check '
          '(${seededStatus.length} attrs)',
        );
      } else {
        try {
          final statusGroup = await modbus.readGroup('status');
          _statusAttrs
            ..clear()
            ..addAll(statusGroup);
        } catch (e) {
          debugPrint('live-cache: seed status failed: $e');
        }
      }
      if (seededData != null) {
        _dataAttrs
          ..clear()
          ..addAll(seededData);
        debugPrint(
          'live-cache: seeded data from boot self-check '
          '(${seededData.length} attrs)',
        );
      } else {
        try {
          final dataGroup = await modbus.readGroup('data');
          _dataAttrs
            ..clear()
            ..addAll(dataGroup);
        } catch (e) {
          debugPrint('live-cache: seed data failed: $e');
        }
      }

      final attrStream = await modbus.watchAttributes(ids: ids);
      _attrSub = attrStream.listen(_onAttrBatch, onError: (Object e) {
        debugPrint('live-cache: attr watch error: $e');
      });

      final healthStream = await modbus.watchHealth();
      _healthSub = healthStream.listen(_onHealth, onError: (Object e) {
        debugPrint('live-cache: health watch error: $e');
      });
    } catch (e) {
      debugPrint('live-cache: modbus watch failed: $e');
    }
  }

  Future<void> dispose() async {
    processStore.removeListener(_onProcessStoreChanged);
    await _attrSub?.cancel();
    await _healthSub?.cancel();
    await _cameraSub?.cancel();
    _attrSub = null;
    _healthSub = null;
    _cameraSub = null;
    _started = false;
  }

  void _onProcessStoreChanged() => _scheduleRemap();

  void _onAttrBatch(List<ModbusAttributeChange> changes) {
    var touched = false;
    for (final c in changes) {
      if (c.kind == ModbusChangeKind.reminder) {
        continue;
      }
      if (_statusIds.contains(c.id)) {
        _statusAttrs[c.id] = c.value;
        touched = true;
      } else if (_dataIds.contains(c.id)) {
        _dataAttrs[c.id] = c.value;
        touched = true;
      }
    }
    if (touched) {
      _scheduleRemap();
    }
  }

  void _onHealth(ModbusHealth health) {
    final gid = health.groupId;
    var changed = false;
    if (gid == 'status') {
      if (_statusTruncated != health.truncated) {
        _statusTruncated = health.truncated;
        changed = true;
      }
    } else if (gid == 'data') {
      if (_dataTruncated != health.truncated) {
        _dataTruncated = health.truncated;
        changed = true;
      }
    }
    if (changed) {
      _scheduleRemap();
    }
  }

  void _applyCameraStatus(int status) {
    if (_cameraStatus == status) {
      return;
    }
    _cameraStatus = status;
    _scheduleRemap();
  }

  void _scheduleRemap() {
    if (_remapScheduled) {
      return;
    }
    _remapScheduled = true;
    scheduleMicrotask(() {
      _remapScheduled = false;
      _publishIfChanged();
    });
  }

  MonitorStatSnapshot _buildSnapshot() {
    Map<String, Object?>? statusOut;
    Map<String, Object?>? dataOut;

    if (_statusAttrs.isNotEmpty) {
      statusOut = DeviceRemoteSnapshotModbusMapper.deviceStatusFromGroup(
        _statusAttrs,
        cameraStatus: _cameraStatus,
      );
      if (_statusTruncated != null) {
        statusOut['modbusStatusReadTruncated'] = _statusTruncated;
      }
    } else {
      statusOut = <String, Object?>{
        'cameraStatus': _cameraStatus,
        if (_statusTruncated != null)
          'modbusStatusReadTruncated': _statusTruncated,
      };
    }

    if (_dataAttrs.isNotEmpty) {
      dataOut =
          DeviceRemoteSnapshotModbusMapper.deviceDataFromGroup(_dataAttrs);
      if (_dataTruncated != null) {
        dataOut['modbusDataReadTruncated'] = _dataTruncated;
      }
    }

    return MonitorStatSnapshot(
      deviceStatus: statusOut,
      deviceData: dataOut,
      processParameters: processStore.snapshot,
    );
  }

  void _publishIfChanged() {
    final next = _buildSnapshot();
    if (!next.changedSince(_published)) {
      return;
    }
    _published = next.copy();
    statHub.publishStat(_published);
  }
}
