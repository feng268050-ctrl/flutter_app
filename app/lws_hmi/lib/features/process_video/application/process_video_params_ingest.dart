import 'dart:convert';

import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_cloud_codec.dart';

/// Normalize LAN / multipart `processParameters` into HMI snapshot JSON.
///
/// Accepts:
/// - HMI envelope (`parameters.process.*`)
/// - lws-ui / mobile camelCase `ProcessParametersData`
/// - empty / invalid → minimal envelope from form [processType] / [materialType]
abstract final class ProcessVideoParamsIngest {
  static String normalizeJson(
    String? raw, {
    required ProcessType processType,
    MaterialType? materialType,
  }) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _minimal(processType, materialType).toJsonString();
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return _minimal(processType, materialType).toJsonString();
      }
      final map = Map<String, Object?>.from(decoded);

      // Prefer cloud/mobile camelCase before envelope parse: a bare
      // ProcessParametersData also has processType and would otherwise become
      // an empty-parameter HMI snapshot.
      final cloud = ProcessParametersCloudCodec.unwrapParamPayload(map);
      if (cloud != null && looksLikeCloudProcessParameters(cloud)) {
        return fromCloudMap(
          cloud,
          fallbackProcessType: processType,
          fallbackMaterialType: materialType,
        ).toJsonString();
      }
      if (looksLikeCloudProcessParameters(map)) {
        return fromCloudMap(
          map,
          fallbackProcessType: processType,
          fallbackMaterialType: materialType,
        ).toJsonString();
      }

      final asEnvelope = ProcessVideoSnapshot.tryParseJson(trimmed);
      if (asEnvelope != null) {
        return ProcessVideoSnapshot(
          processType: asEnvelope.processType,
          materialType: asEnvelope.materialType ?? materialType,
          materialName: asEnvelope.materialName,
          thickness: asEnvelope.thickness,
          gear: asEnvelope.gear,
          parameters: asEnvelope.parameters,
          presetUuid: asEnvelope.presetUuid,
          libraryVersion: asEnvelope.libraryVersion,
        ).toJsonString();
      }
    } catch (_) {
      // fall through to minimal
    }
    return _minimal(processType, materialType).toJsonString();
  }

  static ProcessVideoSnapshot fromCloudMap(
    Map<String, Object?> cloud, {
    required ProcessType fallbackProcessType,
    MaterialType? fallbackMaterialType,
  }) {
    final processTypeRaw = cloud['processType'] ?? cloud['process_type'];
    final processType = processTypeRaw is num
        ? ProcessType.fromWireValue(processTypeRaw.toInt())
        : ProcessType.fromWireValue(
            int.tryParse(processTypeRaw?.toString() ?? '') ??
                fallbackProcessType.wireValue,
          );
    final materialRaw = cloud['materialType'] ?? cloud['material_type'];
    MaterialType? material = fallbackMaterialType;
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
    final gearRaw = cloud['gear'];
    final gear = gearRaw is num
        ? gearRaw.toInt()
        : int.tryParse(gearRaw?.toString() ?? '');
    return ProcessVideoSnapshot(
      processType: processType,
      materialType: material,
      materialName:
          cloud['materialName']?.toString() ?? cloud['material_name']?.toString(),
      thickness: (cloud['thickness'] as num?)?.toDouble(),
      gear: gear,
      parameters: ProcessParametersCloudCodec.parametersFromCloud(cloud),
    );
  }

  static bool looksLikeCloudProcessParameters(Map<String, Object?> map) {
    if (map.containsKey('parameters') && map['parameters'] is Map) {
      return false;
    }
    return map.containsKey('laserPower') ||
        map.containsKey('swingFrequency') ||
        map.containsKey('wireFeedSpeed') ||
        map.containsKey('blowDelay') ||
        map.containsKey('powerRampUp') ||
        map.containsKey('laserDutyCycle');
  }

  static ProcessVideoSnapshot _minimal(
    ProcessType processType,
    MaterialType? materialType,
  ) =>
      ProcessVideoSnapshot(
        processType: processType,
        materialType: materialType,
      );
}
