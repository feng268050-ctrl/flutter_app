import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';

/// Builds a [ProcessVideoSnapshot] from the active Quick/Engineer process state.
abstract final class ProcessVideoSnapshotFactory {
  static ProcessVideoSnapshot fromPreset({
    required ProcessType processType,
    ProcessPreset? preset,
    MaterialType? materialFallback,
  }) {
    final matched = preset;
    return ProcessVideoSnapshot(
      processType: processType,
      materialType: matched?.materialType ?? materialFallback,
      materialName: matched?.materialName,
      thickness: matched?.thickness,
      gear: matched?.gear,
      parameters: matched?.parameters ?? const ProcessParameters.empty(),
      presetUuid: matched?.uuid,
      libraryVersion: matched?.libraryVersion,
    );
  }
}
