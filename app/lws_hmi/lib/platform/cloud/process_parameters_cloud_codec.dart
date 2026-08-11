import 'dart:convert';

import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot_modbus_mapper.dart';

/// Cloud push JSON (lws-ui Gson camelCase) ↔ HMI process presets.
abstract final class ProcessParametersCloudCodec {
  /// Unwrap legacy `{data:…}` envelope or bare [ProcessParametersData] map.
  static Map<String, Object?>? unwrapParamPayload(Object? payload) {
    if (payload is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(payload);
    final data = map['data'];
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
    // Bare entity heuristics.
    if (map.containsKey('laserPower') ||
        map.containsKey('processType') ||
        map.containsKey('name') ||
        map.containsKey('materialType')) {
      return map;
    }
    return null;
  }

  /// Unwrap legacy envelope or bare [ProcessLibrary] map.
  static ({
    int? versionCode,
    int? versionStatus,
    List<Map<String, Object?>> dataList,
  })? unwrapLibPayload(Object? payload) {
    if (payload is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(payload);
    Map<String, Object?> lib;
    final data = map['data'];
    if (data is Map) {
      lib = Map<String, Object?>.from(data);
    } else if (map.containsKey('dataList') || map.containsKey('versionCode')) {
      lib = map;
    } else {
      return null;
    }
    final rawList = lib['dataList'];
    if (rawList is! List) {
      return null;
    }
    final list = <Map<String, Object?>>[
      for (final e in rawList)
        if (e is Map) Map<String, Object?>.from(e),
    ];
    final vc = lib['versionCode'];
    final vs = lib['versionStatus'];
    return (
      versionCode: vc is num ? vc.toInt() : int.tryParse('$vc'),
      versionStatus: vs is num ? vs.toInt() : int.tryParse('$vs'),
      dataList: list,
    );
  }

  static ProcessParameters parametersFromCloud(Map<String, Object?> json) {
    final values = <String, num>{};
    void put(String key, Object? v) {
      if (v is num) {
        values[key] = v;
      } else if (v != null) {
        final n = num.tryParse(v.toString());
        if (n != null) {
          values[key] = n;
        }
      }
    }

    put('process.laser_power', json['laserPower']);
    put('process.laser_duty_cycle', json['laserDutyCycle']);
    put('process.laser_frequency', json['laserFrequency']);
    put('process.piercing_power', json['perforationPower']);
    put('process.piercing_frequency', json['perforationFrequency']);
    put('process.piercing_duty_cycle', json['perforationDutyCycle']);
    put('process.swing_frequency', json['swingFrequency']);
    put('process.swing_width', json['swingWidth']);
    put('process.wire_feeding_speed', json['wireFeedSpeed']);
    put('process.back_draw_length', json['retractLength']);
    put('process.back_draw_speed', json['retractSpeed']);
    put('process.wire_filling_length', json['fillLength']);
    put('process.wire_filling_delay', json['fillDelay']);
    put('process.wire_feeding_delay', json['wireFeedingDelay']);
    put('process.blowing_delay', json['blowDelay']);
    put('process.gas_off_delay', json['closeAirDelay']);
    put('process.light_off_delay', json['closeLightDelay']);
    put('process.power_ramp_up_duration', json['powerRampUp']);
    put('process.power_ramp_down_duration', json['powerRampDown']);
    put('process.spot_welding_duration', json['pointWeldingDuration']);
    put('process.spot_welding_interval', json['pointWeldingInterval']);

    final pierce = json['perforationDuration'];
    if (pierce is num) {
      // HMI catalog is ms (0–2000). Cloud/Java comments say seconds (0.1–2.0).
      values['process.piercing_duration'] =
          pierce <= 20 ? pierce * 1000 : pierce;
    }

    return ProcessParameters(values);
  }

  /// HMI [ProcessVideoSnapshot] → lws-ui `ProcessParametersData` camelCase map.
  ///
  /// Mobile / cloud video catalog parses `processParametersJson` with Gson into
  /// that shape — not the nested HMI envelope (`parameters.process.*`).
  static Map<String, Object?> toCloudMap(ProcessVideoSnapshot snapshot) {
    final process = <String, Object?>{
      for (final e in snapshot.parameters.values.entries) e.key: e.value,
    };
    final out = DeviceRemoteSnapshotModbusMapper.processParametersFromGroup(
      process,
      processType: snapshot.processType.wireValue,
      materialType: snapshot.materialType?.storageValue,
      materialName: snapshot.materialName,
      thickness: snapshot.thickness,
    );
    final pierceMs = snapshot.parameters.values['process.piercing_duration'];
    if (pierceMs != null) {
      out['perforationDuration'] = _piercingDurationToCloud(pierceMs);
    }
    if (snapshot.gear != null) {
      out['gear'] = snapshot.gear;
    }
    return {
      for (final e in out.entries)
        if (e.value != null) e.key: e.value,
    };
  }

  /// Gson-compatible JSON text for `processParametersJson` wire fields.
  static String? processParametersJsonFromSnapshot(
    ProcessVideoSnapshot? snapshot,
  ) {
    if (snapshot == null) {
      return null;
    }
    return jsonEncode(toCloudMap(snapshot));
  }

  static num _piercingDurationToCloud(num ms) =>
      ms <= 20 ? ms : ms / 1000.0;

  static ProcessPreset presetFromCloud(
    Map<String, Object?> json, {
    required ProcessPresetKind kind,
    required String source,
    required bool isBuiltin,
    required String uuid,
    String? libraryVersion,
    int? nowMs,
  }) {
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final processTypeRaw = json['processType'] ?? json['process_type'];
    final processType = processTypeRaw is num
        ? ProcessType.fromWireValue(processTypeRaw.toInt())
        : ProcessType.fromWireValue(
            int.tryParse(processTypeRaw?.toString() ?? '') ?? 0,
          );
    final materialRaw = json['materialType'] ?? json['material_type'];
    MaterialType? material;
    if (materialRaw is num) {
      try {
        material = MaterialType.fromStorageValue(materialRaw.toInt());
      } catch (_) {}
    } else if (materialRaw != null) {
      final n = int.tryParse(materialRaw.toString());
      if (n != null) {
        try {
          material = MaterialType.fromStorageValue(n);
        } catch (_) {}
      }
    }
    final name = json['name']?.toString().trim() ?? '';
    return ProcessPreset(
      uuid: uuid,
      name: name.isEmpty ? 'Cloud preset' : name,
      kind: kind,
      source: source,
      isBuiltin: isBuiltin,
      processType: processType,
      materialType: material,
      materialName:
          json['materialName']?.toString() ?? json['material_name']?.toString(),
      thickness: (json['thickness'] as num?)?.toDouble(),
      gear: (json['gear'] as num?)?.toInt(),
      parameters: parametersFromCloud(json),
      libraryVersion: libraryVersion,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }
}
