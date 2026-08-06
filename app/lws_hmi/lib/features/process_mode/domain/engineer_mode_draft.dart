import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_parameter_defaults.dart';

/// In-memory engineer workspace draft.
///
/// Matches lws-ui: field edits live in a per-process-type session (not Room).
/// [EngineerModeSessionStore] keeps the session across leave/re-enter
/// (`engineer_data_cache:{type}`). [Save as Favorite] is the intentional DB
/// write; Reset restores baseline / built-in default for the active type.
final class EngineerModeDraft {
  const EngineerModeDraft({
    required this.preset,
    required this.baseline,
    required this.unsaved,
    required this.fromQuickHandoff,
  });

  /// Working copy shown in the form.
  final ProcessPreset preset;

  /// Snapshot for dirty-state and discard confirmation.
  final ProcessPreset baseline;

  /// True when [preset] is not yet stored as a user row (or dirty vs DB).
  final bool unsaved;

  /// Opened from Quick Mode More Parameters.
  final bool fromQuickHandoff;

  bool get isReadOnly => preset.isBuiltin;

  bool get isDirty {
    if (unsaved) {
      return true;
    }
    return !_sameContent(preset, baseline);
  }

  EngineerModeDraft copyWith({
    ProcessPreset? preset,
    ProcessPreset? baseline,
    bool? unsaved,
    bool? fromQuickHandoff,
  }) {
    return EngineerModeDraft(
      preset: preset ?? this.preset,
      baseline: baseline ?? this.baseline,
      unsaved: unsaved ?? this.unsaved,
      fromQuickHandoff: fromQuickHandoff ?? this.fromQuickHandoff,
    );
  }

  EngineerModeDraft resetToBaseline() => copyWith(
        preset: baseline,
        unsaved: unsaved && fromQuickHandoff,
      );

  /// Load a library row into the workspace (built-in stays read-only).
  static EngineerModeDraft fromLibrary(ProcessPreset source) {
    final resolved = ProcessParameterDefaults.resolve(source);
    return EngineerModeDraft(
      preset: resolved,
      baseline: resolved,
      unsaved: false,
      fromQuickHandoff: false,
    );
  }

  /// Quick → Engineer handoff: in-memory user draft, no DB write yet.
  static EngineerModeDraft fromQuickSource(ProcessPreset source) {
    final resolved = ProcessParameterDefaults.resolve(source);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final draft = ProcessPreset(
      uuid: 'draft-${resolved.uuid}',
      name: resolved.name.isEmpty ? _defaultName(resolved) : resolved.name,
      kind: ProcessPresetKind.user,
      source: 'user',
      isBuiltin: false,
      processType: resolved.processType,
      materialType: resolved.materialType,
      materialName: resolved.materialName,
      thickness: resolved.thickness,
      gear: resolved.gear,
      parameters: resolved.parameters,
      createdAtMs: now,
      updatedAtMs: now,
    );
    return EngineerModeDraft(
      preset: draft,
      baseline: draft,
      unsaved: true,
      fromQuickHandoff: true,
    );
  }

  static String _defaultName(ProcessPreset source) {
    final material =
        source.materialName ?? source.materialType?.englishName ?? 'Process';
    if (source.processType.isCleaning) {
      final swing = source.parameters.values['process.swing_width'];
      return swing == null ? material : '$material-${swing}mm';
    }
    final thickness = source.thickness;
    return thickness == null ? material : '$material-${thickness}mm';
  }

  static bool _sameContent(ProcessPreset a, ProcessPreset b) {
    if (a.name != b.name ||
        a.materialType != b.materialType ||
        a.materialName != b.materialName ||
        a.thickness != b.thickness ||
        a.gear != b.gear) {
      return false;
    }
    if (a.parameters.values.length != b.parameters.values.length) {
      return false;
    }
    for (final entry in a.parameters.values.entries) {
      if (b.parameters.values[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
