import 'dart:convert';

import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Frozen process context captured for a work recording (lws-ui snapshot parity).
///
/// Persisted as [toJson] / [processParametersJson]; never a live preset FK alone.
final class ProcessVideoSnapshot {
  const ProcessVideoSnapshot({
    required this.processType,
    this.materialType,
    this.materialName,
    this.thickness,
    this.gear,
    this.parameters = const ProcessParameters.empty(),
    this.presetUuid,
    this.libraryVersion,
  });

  final ProcessType processType;
  final MaterialType? materialType;
  final String? materialName;
  final double? thickness;
  final int? gear;
  final ProcessParameters parameters;
  final String? presetUuid;
  final String? libraryVersion;

  Map<String, Object?> toJson() => {
        'processType': processType.wireValue,
        if (materialType != null) 'materialType': materialType!.storageValue,
        if (materialName != null) 'materialName': materialName,
        if (thickness != null) 'thickness': thickness,
        if (gear != null) 'gear': gear,
        'parameters': parameters.toJson(),
        if (presetUuid != null) 'presetUuid': presetUuid,
        if (libraryVersion != null) 'libraryVersion': libraryVersion,
      };

  String toJsonString() => jsonEncode(toJson());

  static ProcessVideoSnapshot fromJson(Map<String, Object?> json) {
    final processTypeRaw = json['processType'];
    if (processTypeRaw is! int) {
      throw const FormatException('processType must be int');
    }
    final materialRaw = json['materialType'];
    return ProcessVideoSnapshot(
      processType: ProcessType.fromWireValue(processTypeRaw),
      materialType: materialRaw is int
          ? MaterialType.fromStorageValue(materialRaw)
          : null,
      materialName: json['materialName'] as String?,
      thickness: (json['thickness'] as num?)?.toDouble(),
      gear: json['gear'] as int?,
      parameters: ProcessParameters.fromJson(json['parameters']),
      presetUuid: json['presetUuid'] as String?,
      libraryVersion: json['libraryVersion'] as String?,
    );
  }

  static ProcessVideoSnapshot? tryParseJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

/// Local-only upload status reserved for Phase F (lws-ui [VideoUploadStatus]).
abstract final class ProcessVideoUploadStatus {
  static const notInitiated = 0;
  static const coverUploaded = 1;
  static const videoUploading = 2;
  static const videoUploaded = 3;
}

/// Indexed work recording row (lws-ui `ProcessParamsVideo` / `t_params_process_video`).
final class ProcessVideoRecord {
  const ProcessVideoRecord({
    this.id,
    required this.videoId,
    required this.videoPath,
    required this.processType,
    this.materialType,
    required this.processParametersJson,
    required this.fileSize,
    required this.durationMs,
    this.resolution,
    required this.createTimeMs,
    this.uploadStatus = ProcessVideoUploadStatus.notInitiated,
    this.uploadProgress = 0,
    this.coverUrl,
    this.videoUrl,
  });

  final int? id;
  final String videoId;
  final String videoPath;
  final ProcessType processType;
  final MaterialType? materialType;
  final String processParametersJson;
  final int fileSize;
  final int durationMs;
  final String? resolution;
  final int createTimeMs;
  final int uploadStatus;
  final int uploadProgress;
  final String? coverUrl;
  final String? videoUrl;

  ProcessVideoSnapshot? get snapshot =>
      ProcessVideoSnapshot.tryParseJson(processParametersJson);

  DateTime get createTime =>
      DateTime.fromMillisecondsSinceEpoch(createTimeMs, isUtc: true).toLocal();
}
