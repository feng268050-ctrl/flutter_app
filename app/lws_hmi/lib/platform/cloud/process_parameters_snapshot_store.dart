import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Process-lifetime last-applied / last-selected process parameters for remote
/// snapshot (lws-ui `ProcessParametersSnapshotStore` parity).
///
/// [ChangeNotifier] so LAN Monitor SSE LiveCache can emit `stat` on updates.
final class ProcessParametersSnapshotStore extends ChangeNotifier {
  ProcessParametersSnapshotStore._();
  static final ProcessParametersSnapshotStore instance =
      ProcessParametersSnapshotStore._();

  Map<String, Object?>? _snapshot;
  String _commonUseText = 'unknown';

  Map<String, Object?>? get snapshot =>
      _snapshot == null ? null : Map<String, Object?>.from(_snapshot!);

  String get commonUseText => _commonUseText;

  void updateFromPreset(ProcessPreset preset, Map<String, Object?> wireFields) {
    _snapshot = {
      ...wireFields,
      'name': preset.name,
      'materialType': preset.materialType?.storageValue,
      'materialName':
          preset.materialName ??
          preset.materialType?.englishName ??
          preset.materialType?.label,
      'thickness': preset.thickness,
      'processType': preset.processType.wireValue,
      'dataType': switch (preset.kind) {
        ProcessPresetKind.quick => 0,
        ProcessPresetKind.engineerPreset => 1,
        ProcessPresetKind.user => 2,
      },
      if (preset.id != null) 'originId': preset.id,
    };
    final material = (preset.materialName ??
            preset.materialType?.englishName ??
            preset.materialType?.label ??
            '')
        .trim();
    _commonUseText = material.isEmpty ? 'unknown' : material;
    notifyListeners();
  }

  void updateRaw(Map<String, Object?> fields, {String? commonUseText}) {
    _snapshot = Map<String, Object?>.from(fields);
    if (commonUseText != null && commonUseText.trim().isNotEmpty) {
      _commonUseText = commonUseText.trim();
    }
    notifyListeners();
  }

  void clear() {
    _snapshot = null;
    _commonUseText = 'unknown';
    notifyListeners();
  }
}
